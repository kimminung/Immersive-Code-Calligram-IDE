import Foundation
import RealityKit
import Observation

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

/// Owns the RealityKit entities for one scene (immersive space or window preview)
/// and swaps the calligram model whenever the program output changes.
@Observable
@MainActor
final class CalligramSceneController {
    enum Mode {
        /// visionOS immersive space: origin at the floor, entity floats in front of the user.
        case immersive
        /// macOS/iOS window: entity centered at the origin, viewed by a virtual camera.
        case preview
        /// iPhone/iPad AR: root is parented to a plane anchor, no sky dome or ground grid.
        case ar
    }

    /// How far the calligram floats above the detected surface in AR mode (meters).
    private static let arLift = SIMD3<Float>(0, 0.45, 0)

    /// Add this to the `RealityView` content.
    let root = Entity()
    /// Virtual camera used only in `.preview` mode.
    let cameraEntity = PerspectiveCamera()

    private let holder = Entity()
    private let pivot = Entity()
    private var calligramModel: ModelEntity?
    private var atlasTexture: TextureResource?
    /// Shader-graph template with the atlas bound; `nil` when the graph failed to load.
    private var iridescentTemplate: ShaderGraphMaterial?
    private var mode: Mode = .immersive
    private var hasStartedBuildingScene = false
    private var isSceneReady = false

    /// `apply` can be called (via `.task(id:)`) before `makeScene` finishes loading textures.
    /// The most recent request is parked here and replayed once the scene is ready.
    private var pendingApply: (output: CalligramProgramOutput?, settings: CalligramRenderSettings)?

    /// Human-readable summary of the last applied mesh, for the control panel.
    private(set) var lastBuildSummary = ""

    /// Whether glyphs use the view-dependent iridescent shader (false = flat unlit fallback).
    private(set) var isIridescentMaterialAvailable = false

    // MARK: - Scene setup

    func makeScene(mode: Mode) async {
        guard !hasStartedBuildingScene else { return }
        hasStartedBuildingScene = true
        self.mode = mode
        SpinSystem.registerIfNeeded()

        root.name = "CalligramRoot"
        holder.name = "CalligramHolder"
        pivot.name = "CalligramPivot"
        holder.addChild(pivot)
        root.addChild(holder)

        switch mode {
        case .immersive:
            holder.position = CalligramRenderSettings().immersivePosition
        case .preview:
            holder.position = .zero
            cameraEntity.camera.fieldOfViewInDegrees = 55
            cameraEntity.look(at: .zero, from: SIMD3<Float>(0, 0.3, 2.4), relativeTo: nil)
        case .ar:
            holder.position = Self.arLift
        }

        // The real world is the backdrop in AR; the procedural sky and grid would hide it.
        if mode != .ar {
            await addSkyDome()
            await addGroundGrid()
        }
        await loadGlyphAtlas()
        await loadIridescentMaterial()

        isSceneReady = true
        if let pending = pendingApply {
            pendingApply = nil
            await apply(output: pending.output, settings: pending.settings)
        }
    }

    private func addSkyDome() async {
        guard let image = EnvironmentTextureRenderer.makeSkyImage(),
              let texture = try? await TextureResource(image: image, options: .init(semantic: .color)) else { return }
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        // Render the inside of the sphere.
        material.faceCulling = .front
        let dome = ModelEntity(mesh: .generateSphere(radius: 40), materials: [material])
        dome.name = "SkyDome"
        root.addChild(dome)
    }

    private func addGroundGrid() async {
        guard let image = EnvironmentTextureRenderer.makeGroundGridImage(),
              let texture = try? await TextureResource(image: image, options: .init(semantic: .color)) else { return }
        var material = UnlitMaterial()
        material.color = .init(tint: PlatformColor(red: 0.45, green: 0.8, blue: 0.95, alpha: 1), texture: .init(texture))
        material.blending = .transparent(opacity: .init(scale: 0.35, texture: .init(texture)))
        material.faceCulling = .none
        let plane = ModelEntity(mesh: .generatePlane(width: 12, depth: 12), materials: [material])
        plane.name = "GroundGrid"
        plane.position = mode == .immersive ? SIMD3<Float>(0, 0.002, 0) : SIMD3<Float>(0, -0.9, 0)
        root.addChild(plane)
    }

    private func loadGlyphAtlas() async {
        guard let image = GlyphAtlasRenderer.makeImage() else { return }
        atlasTexture = try? await TextureResource(
            image: image,
            options: .init(semantic: .color, mipmapsMode: .allocateAndGenerateAll))
    }

    private func loadIridescentMaterial() async {
        #if targetEnvironment(simulator)
        // The iOS simulator's Metal backend caps shader buffers below what the shader graph needs
        // and fails pipeline compilation; use the flat unlit glyphs there. Devices are unaffected.
        isIridescentMaterialAvailable = false
        return
        #else
        guard let atlasTexture, var material = await IridescentGlyphMaterial.load() else {
            isIridescentMaterialAvailable = false
            return
        }
        do {
            try material.setParameter(name: "atlas", value: .textureResource(atlasTexture))
            iridescentTemplate = material
            isIridescentMaterialAvailable = true
        } catch {
            print("[CalligramSceneController] atlas parameter rejected: \(error)")
            isIridescentMaterialAvailable = false
        }
        #endif
    }

    // MARK: - Applying program output

    func apply(output: CalligramProgramOutput?, settings: CalligramRenderSettings) async {
        guard isSceneReady else {
            pendingApply = (output, settings)
            return
        }

        pivot.components.set(SpinComponent(speed: settings.isSpinning ? settings.spinSpeed : 0))
        switch mode {
        case .preview: holder.position = .zero
        case .immersive: holder.position = settings.immersivePosition
        case .ar: break // Placement is owned by the plane anchor and the user's gestures.
        }

        guard let output, !output.points.isEmpty, let atlasTexture else {
            calligramModel?.removeFromParent()
            calligramModel = nil
            lastBuildSummary = atlasTexture == nil ? "글리프 아틀라스 로드 실패" : "표시할 글리프 없음"
            return
        }

        let points = output.points
        let meshData = await Task.detached(priority: .userInitiated) {
            CalligramMeshBuilder.build(points: points, settings: settings)
        }.value
        guard !Task.isCancelled, !meshData.positions.isEmpty else { return }

        var descriptor = MeshDescriptor(name: "Calligram")
        descriptor.positions = MeshBuffers.Positions(meshData.positions)
        descriptor.normals = MeshBuffers.Normals(meshData.normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(meshData.textureCoordinates)
        descriptor.primitives = .triangles(meshData.indices)
        descriptor.materials = .perFace(meshData.materialIndices)

        let mesh: MeshResource
        do {
            mesh = try MeshResource.generate(from: [descriptor])
        } catch {
            lastBuildSummary = "메시 생성 실패: \(error.localizedDescription)"
            return
        }

        let materials = makeMaterials(palette: meshData.palette, atlas: atlasTexture, settings: settings)
        if let model = calligramModel {
            model.model = ModelComponent(mesh: mesh, materials: materials.list)
        } else {
            let model = ModelEntity(mesh: mesh, materials: materials.list)
            model.name = "Calligram"
            pivot.addChild(model)
            calligramModel = model
        }
        let planes = settings.alwaysVisible ? "교차 2면" : "단면"
        lastBuildSummary = "쿼드 \(meshData.quadCount.formatted()) · \(planes) · \(materials.kind) \(materials.list.count)"
    }

    // MARK: - Materials

    /// One material per palette entry. Prefers the iridescent shader graph and falls back to
    /// a flat unlit material if the graph could not be loaded or a parameter is rejected.
    private func makeMaterials(palette: [SIMD4<Float>],
                               atlas: TextureResource,
                               settings: CalligramRenderSettings) -> (list: [any Material], kind: String) {
        if let template = iridescentTemplate {
            var materials: [any Material] = []
            materials.reserveCapacity(palette.count)
            var failed = false
            for color in palette {
                var material = template
                do {
                    try material.setParameter(name: "baseColor", value: .simd3Float(SIMD3<Float>(color.x, color.y, color.z)))
                    try material.setParameter(name: "baseOpacity", value: .float(color.w))
                    try material.setParameter(name: "iridescence", value: .float(settings.iridescence))
                } catch {
                    print("[CalligramSceneController] shader parameter rejected: \(error)")
                    failed = true
                    break
                }
                materials.append(material)
            }
            if !failed {
                return (materials, "무지갯빛")
            }
            iridescentTemplate = nil
            isIridescentMaterialAvailable = false
        }
        return (palette.map { makeUnlitGlyphMaterial(color: $0, texture: atlas) }, "단색")
    }

    private func makeUnlitGlyphMaterial(color: SIMD4<Float>, texture: TextureResource) -> UnlitMaterial {
        var material = UnlitMaterial()
        let tint = PlatformColor(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1)
        material.color = .init(tint: tint, texture: .init(texture))
        // The atlas is white-on-transparent, so its red channel doubles as the opacity mask.
        material.blending = .transparent(opacity: .init(scale: color.w, texture: .init(texture)))
        // Alpha masking avoids sort-order artifacts between thousands of overlapping quads.
        material.opacityThreshold = 0.35
        material.faceCulling = .none
        return material
    }

    // MARK: - AR manipulation

    /// Uniform scale applied by the pinch gesture in AR mode.
    func setARScale(_ scale: Float) {
        guard mode == .ar else { return }
        holder.scale = SIMD3<Float>(repeating: min(max(scale, 0.25), 4))
    }

    /// Manual yaw from the drag gesture in AR mode; the auto-spin on the pivot adds on top.
    func setARYaw(_ yaw: Float) {
        guard mode == .ar else { return }
        holder.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
    }

    // MARK: - Preview camera

    /// Positions the virtual camera on a sphere around the origin (preview mode only).
    func updatePreviewCamera(yaw: Float, pitch: Float, distance: Float) {
        let clampedPitch = min(max(pitch, -1.4), 1.4)
        let x = distance * cos(clampedPitch) * sin(yaw)
        let y = distance * sin(clampedPitch)
        let z = distance * cos(clampedPitch) * cos(yaw)
        cameraEntity.look(at: .zero, from: SIMD3<Float>(x, y, z), relativeTo: nil)
    }
}
