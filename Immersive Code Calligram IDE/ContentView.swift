import SwiftUI

/// Main window.
/// - Regular width (Mac, iPad landscape, visionOS): editor | preview (non-visionOS) | controls side by side.
/// - Compact width (iPhone, iPad Split View): tabs for code, preview, and settings.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 560)
        #endif
        .task {
            await appModel.runIfNeeded()
        }
    }

    // MARK: - Regular width

    private var regularLayout: some View {
        HStack(spacing: 0) {
            CodeEditorView()
                .frame(minWidth: 300, idealWidth: 460)

            Divider()

            #if !os(visionOS)
            PreviewCanvasView()
                .frame(minWidth: 240)
                .layoutPriority(1)
            Divider()
            #endif

            ControlPanelView()
                .frame(width: 280)
        }
    }

    // MARK: - Compact width

    private var compactLayout: some View {
        TabView {
            Tab("코드", systemImage: "chevron.left.forwardslash.chevron.right") {
                CodeEditorView()
            }
            #if !os(visionOS)
            Tab("프리뷰", systemImage: "cube.transparent") {
                PreviewCanvasView()
                    .ignoresSafeArea(edges: .bottom)
            }
            #endif
            Tab("설정", systemImage: "slider.horizontal.3") {
                ControlPanelView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
