import SwiftUI

/// Monospaced editor for CalligramScript with a sample picker.
struct CodeEditorView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var model = appModel
        VStack(spacing: 0) {
            header
            Divider()
            TextEditor(text: $model.source)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .lineSpacing(2)
                .autocorrectionDisabled()
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                #endif
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.18))
        }
    }

    private var header: some View {
        HStack {
            Label("CalligramScript", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)
            Spacer()
            Menu {
                ForEach(CalligramSamples.all) { sample in
                    Button(sample.title) {
                        appModel.loadSample(sample)
                    }
                }
            } label: {
                Label("샘플", systemImage: "doc.text")
            }
            .menuStyle(.button)
            Button {
                Task { await appModel.run() }
            } label: {
                Label("실행", systemImage: "play.fill")
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appModel.isRunning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

#Preview {
    CodeEditorView()
        .environment(AppModel())
        .frame(width: 520, height: 420)
}
