import SwiftUI
import RealityKit

#if os(iOS) && !targetEnvironment(simulator)
/// AR placement mode for iPhone and iPad (real devices only).
///
/// Shows the back-camera feed, anchors the calligram to the first horizontal surface RealityKit
/// finds (table, floor), and lets the user rotate it by dragging and resize it by pinching.
/// The simulator has no camera, so this view is not compiled there; `ContentView` falls back to
/// the virtual-camera preview.
struct ARCalligramView: View {
    @Environment(AppModel.self) private var appModel
    @State private var controller = CalligramSceneController()
    @State private var trackingSession = SpatialTrackingSession()
    @State private var anchor: AnchorEntity?
    @State private var anchorSubscription: EventSubscription?

    @State private var isAnchored = false
    @State private var statusMessage = "바닥이나 책상 같은 평면을 천천히 비춰 주세요"
    @State private var hasCameraAccess = true

    @State private var scale: Float = 1
    @State private var scaleBaseline: Float?
    @State private var yaw: Float = 0
    @State private var lastDragWidth: CGFloat = 0

    private static let planeTarget = AnchoringComponent.Target.plane(.horizontal, classification: .any, minimumBounds: [0.3, 0.3])

    var body: some View {
        ZStack {
            // Camera feed fills the whole screen; the banners below stay inside the safe area.
            RealityView { content in
                content.camera = .spatialTracking
                await startTracking()

                await controller.makeScene(mode: .ar)
                let anchor = AnchorEntity(plane: .horizontal, classification: .any, minimumBounds: [0.3, 0.3])
                anchor.name = "CalligramPlaneAnchor"
                anchor.addChild(controller.root)
                content.add(anchor)
                self.anchor = anchor

                anchorSubscription = content.subscribe(to: SceneEvents.AnchoredStateChanged.self, on: anchor) { event in
                    isAnchored = event.isAnchored
                    if event.isAnchored {
                        statusMessage = "평면에 배치했습니다 · 드래그: 회전 · 핀치: 크기"
                    }
                }
            }
            .ignoresSafeArea()
            .gesture(rotateGesture)
            .simultaneousGesture(scaleGesture)

            VStack {
                statusBanner
                Spacer()
                bottomBar
            }
        }
        .task(id: appModel.revision) {
            await controller.apply(output: appModel.output, settings: appModel.settings)
        }
    }

    // MARK: - Tracking

    private func startTracking() async {
        let configuration = SpatialTrackingSession.Configuration(
            tracking: [.camera, .world, .plane],
            sceneUnderstanding: [],
            camera: .back)
        guard let unavailable = await trackingSession.run(configuration) else { return }
        if unavailable.missingCameraAuthorization == true {
            hasCameraAccess = false
            statusMessage = "카메라 접근이 꺼져 있습니다. 설정 > 개인정보 보호 > 카메라에서 허용해 주세요."
        } else if unavailable.anchor.contains(.plane) {
            statusMessage = "이 기기는 평면 추적을 지원하지 않습니다."
        }
    }

    /// Looks for a new surface (usually the one currently in view) and resets rotation and scale.
    private func replace() {
        scale = 1
        yaw = 0
        controller.setARScale(1)
        controller.setARYaw(0)
        isAnchored = false
        statusMessage = "새 평면을 찾는 중…"
        anchor?.reanchor(Self.planeTarget, preservingWorldTransform: false)
    }

    // MARK: - Gestures

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let delta = Float(value.translation.width - lastDragWidth)
                yaw += delta * 0.01
                lastDragWidth = value.translation.width
                controller.setARYaw(yaw)
            }
            .onEnded { _ in lastDragWidth = 0 }
    }

    private var scaleGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if scaleBaseline == nil { scaleBaseline = scale }
                scale = min(max((scaleBaseline ?? scale) * Float(value.magnification), 0.25), 4)
                controller.setARScale(scale)
            }
            .onEnded { _ in scaleBaseline = nil }
    }

    // MARK: - Overlays

    private var statusBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: hasCameraAccess ? (isAnchored ? "checkmark.circle.fill" : "viewfinder") : "camera.fill.badge.ellipsis")
                .foregroundStyle(isAnchored ? .green : .yellow)
            Text(statusMessage)
                .font(.footnote)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text(controller.lastBuildSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                replace()
            } label: {
                Label("다시 배치", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
#endif
