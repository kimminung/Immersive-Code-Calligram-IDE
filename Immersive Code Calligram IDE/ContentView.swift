import SwiftUI

/// Main window.
/// - Regular width (Mac, iPad landscape, visionOS): editor | preview (non-visionOS) | controls side by side.
/// - Compact width (iPhone, iPad Split View): tabs for code, preview, AR (real iOS devices), and settings.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    #if os(iOS)
    /// Which view fills the preview column on iPad. AR is offered only on real devices.
    enum PreviewMode: String, CaseIterable, Identifiable {
        case virtual = "가상 카메라"
        case ar = "AR"
        var id: String { rawValue }
    }

    @State private var previewMode: PreviewMode = .virtual
    #endif

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
            previewColumn
                .frame(minWidth: 240)
                .layoutPriority(1)
            Divider()
            #endif

            ControlPanelView()
                .frame(width: 280)
        }
    }

    #if !os(visionOS)
    /// Preview area for the regular layout. On iPad with a camera it can switch to AR placement.
    @ViewBuilder
    private var previewColumn: some View {
        #if os(iOS)
        if ARSupport.isAvailable {
            VStack(spacing: 0) {
                Picker("프리뷰 방식", selection: $previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
                switch previewMode {
                case .virtual:
                    PreviewCanvasView()
                case .ar:
                    arViewIfAvailable
                }
            }
        } else {
            PreviewCanvasView()
        }
        #else
        PreviewCanvasView()
        #endif
    }
    #endif

    // MARK: - Compact width

    private var compactLayout: some View {
        TabView {
            Tab("코드", systemImage: "chevron.left.forwardslash.chevron.right") {
                CodeEditorView()
            }
            #if !os(visionOS)
            Tab("프리뷰", systemImage: "cube.transparent") {
                PreviewCanvasView()
            }
            #endif
            #if os(iOS)
            if ARSupport.isAvailable {
                Tab("AR", systemImage: "arkit") {
                    arViewIfAvailable
                }
            }
            #endif
            Tab("설정", systemImage: "slider.horizontal.3") {
                ControlPanelView()
            }
        }
    }

    #if os(iOS)
    /// The AR view exists only in device builds; the simulator never reaches this branch
    /// because `ARSupport.isAvailable` is false there, but the fallback keeps the code compiling.
    @ViewBuilder
    private var arViewIfAvailable: some View {
        #if targetEnvironment(simulator)
        PreviewCanvasView()
        #else
        ARCalligramView()
        #endif
    }
    #endif
}

#Preview {
    ContentView()
        .environment(AppModel())
}
