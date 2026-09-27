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
        RealityView { content in
            content.camera = .virtual
            await controller.makeScene(mode: .preview)
            content.add(controller.root)
            content.add(controller.cameraEntity)
            controller.updatePreviewCamera(yaw: yaw, pitch: pitch, distance: distance)
        } update: { _ in
            controller.updatePreviewCamera(yaw: yaw, pitch: pitch, distance: distance)
        }
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .task(id: appModel.revision) {
            await controller.apply(output: appModel.output, settings: appModel.settings)
        }
        .overlay(alignment: .bottomLeading) {
            Text(controller.lastBuildSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .overlay(alignment: .topTrailing) {
            Text("드래그: 회전 · 핀치: 거리")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
        }
        .background(Color.black)
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
