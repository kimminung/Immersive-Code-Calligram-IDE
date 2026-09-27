import SwiftUI

@main
struct MyApp: App {
    @State private var appModel = AppModel()
    #if os(visionOS)
    @State private var immersionStyle: ImmersionStyle = .full
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 1180, height: 720)

        #if os(visionOS)
        ImmersiveSpace(id: AppModel.immersiveSpaceID) {
            ImmersiveCalligramView()
                .environment(appModel)
        }
        .immersionStyle(selection: $immersionStyle, in: .full)
        #endif
    }
}
