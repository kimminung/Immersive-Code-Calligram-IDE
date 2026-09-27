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
    }

    /// Add this to the `RealityView` content.
    let root = Entity()
    /// Virtual camera used only in `.preview` mode.
    let cameraEntity = PerspectiveCamera()

    private let holder = Entity()
    private let pivot = Entity()
    private var calligramModel: ModelEntity?
    private var atlasTexture: TextureResource?
    private var mode: Mode = .immersive
    private var hasStartedBuildingScene = false
    private var isSceneReady = false

    /// `apply` can be called (via `.task(id:)`) before `makeScene` finishes loading textures.
    /// The most recent request is parked here and replayed once the scene is ready.
    private var pendingApply: (output: CalligramProgramOutput?, settings: CalligramRenderSettings)?

    /// Human-readable summary of the last applied mesh, for the control panel.
    private(set) var lastBuildSummary = ""

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
        }

        await addSkyDome()
        await addGroundGrid()
        await loadGlyphAtlas()

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

    // MARK: - Applying program output

    func apply(output: CalligramProgramOutput?, settings: CalligramRenderSettings) async {
        guard isSceneReady else {
            pendingApply = (output, settings)
            return
        }

        pivot.components.set(SpinComponent(speed: settings.isSpinning ? settings.spinSpeed : 0))
        holder.position = mode == .preview ? .zero : settings.immersivePosition

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

        let materials = meshData.palette.map { makeGlyphMaterial(color: $0, texture: atlasTexture) }
        if let model = calligramModel {
            model.model = ModelComponent(mesh: mesh, materials: materials)
        } else {
            let model = ModelEntity(mesh: mesh, materials: materials)
            model.name = "Calligram"
            pivot.addChild(model)
            calligramModel = model
        }
        lastBuildSummary = "쿼드 \(meshData.quadCount.formatted()) · 머티리얼 \(materials.count)"
    }

    private func makeGlyphMaterial(color: SIMD4<Float>, texture: TextureResource) -> UnlitMaterial {
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
