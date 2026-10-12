import SwiftUI
import RealityKit

#if !os(visionOS)
/// In-window preview for macOS and iOS using a virtual camera.
/// Drag to orbit, pinch (or scroll-zoom on Mac trackpad) to change distance.
struct PreviewCanvasView: View {
    @Environment(AppModel.self) private var appModel
    @State private var controller = CalligramSceneController()

    @State private var yaw: Float = 0.35
    @State private var pitch: Float = 0.18
    @State private var distance: Float = 2.4
    @State private var lastDragTranslation: CGSize = .zero
    @State private var magnificationBaseline: Float?

    var body: some View {
        ZStack {
            // The 3D view may extend under bars; the captions below stay inside the safe area.
            RealityView { content in
                content.camera = .virtual
                await controller.makeScene(mode: .preview)
                content.add(controller.root)
                content.add(controller.cameraEntity)
                controller.updatePreviewCamera(yaw: yaw, pitch: pitch, distance: distance)
            } update: { _ in
                controller.updatePreviewCamera(yaw: yaw, pitch: pitch, distance: distance)
            }
            .ignoresSafeArea()
            .gesture(orbitGesture)
            .simultaneousGesture(zoomGesture)

            VStack {
                HStack {
                    Spacer()
                    caption("드래그: 회전 · 핀치: 거리")
                }
                Spacer()
                HStack {
                    caption(controller.lastBuildSummary)
                    Spacer()
                }
            }
            .padding(8)
            .allowsHitTesting(false)
        }
        .task(id: appModel.revision) {
            await controller.apply(output: appModel.output, settings: appModel.settings)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
            .opacity(text.isEmpty ? 0 : 1)
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let deltaX = Float(value.translation.width - lastDragTranslation.width)
                let deltaY = Float(value.translation.height - lastDragTranslation.height)
                yaw -= deltaX * 0.008
                pitch = min(max(pitch + deltaY * 0.008, -1.4), 1.4)
                lastDragTranslation = value.translation
            }
            .onEnded { _ in
                lastDragTranslation = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnificationBaseline == nil { magnificationBaseline = distance }
                let baseline = magnificationBaseline ?? distance
                distance = min(max(baseline / Float(value.magnification), 0.6), 8)
            }
            .onEnded { _ in
                magnificationBaseline = nil
            }
    }
}
#endif
