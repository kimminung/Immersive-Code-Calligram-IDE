import SwiftUI
import RealityKit

#if os(visionOS)
/// Content of the immersive space: sky dome, ground grid, and the code calligram entity.
struct ImmersiveCalligramView: View {
    @Environment(AppModel.self) private var appModel
    @State private var controller = CalligramSceneController()

    var body: some View {
        RealityView { content in
            await controller.makeScene(mode: .immersive)
            content.add(controller.root)
        }
        .task(id: appModel.revision) {
            await controller.apply(output: appModel.output, settings: appModel.settings)
        }
        .onAppear {
            appModel.immersiveState = .open
        }
        .onDisappear {
            // The system can dismiss the space (e.g. Digital Crown); keep the button state honest.
            appModel.immersiveState = .closed
        }
    }
}
#endif
