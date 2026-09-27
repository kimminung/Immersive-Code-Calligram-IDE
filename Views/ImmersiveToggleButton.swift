import SwiftUI

#if os(visionOS)
/// Opens or dismisses the calligram immersive space and keeps `AppModel.immersiveState` in sync.
struct ImmersiveToggleButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Label(title, systemImage: iconName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(appModel.immersiveState == .inTransition)
    }

    private var title: String {
        switch appModel.immersiveState {
        case .closed: return "이머시브 공간 진입"
        case .inTransition: return "전환 중…"
        case .open: return "이머시브 공간 나가기"
        }
    }

    private var iconName: String {
        appModel.immersiveState == .open ? "arrow.down.right.and.arrow.up.left" : "visionpro"
    }

    private func toggle() async {
        switch appModel.immersiveState {
        case .closed:
            appModel.immersiveState = .inTransition
            switch await openImmersiveSpace(id: AppModel.immersiveSpaceID) {
            case .opened:
                appModel.immersiveState = .open
            case .userCancelled, .error:
                fallthrough
            @unknown default:
                appModel.immersiveState = .closed
            }
        case .open:
            appModel.immersiveState = .inTransition
            await dismissImmersiveSpace()
            appModel.immersiveState = .closed
        case .inTransition:
            break
        }
    }
}
#endif
