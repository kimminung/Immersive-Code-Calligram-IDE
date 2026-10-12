import SwiftUI

/// Monospaced editor for CalligramScript with a sample picker and a live math-notation panel.
struct CodeEditorView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        @Bindable var model = appModel
        VStack(spacing: 0) {
            header
            Divider()
            TextEditor(text: $model.source)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .lineSpacing(2)
                .autocorrectionDisabled()
                .focused($isEditorFocused)
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.asciiCapable)
                #endif
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.18))

            if appModel.isFormulaPanelVisible {
                Divider()
                formulaPanel
            }
        }
        #if os(iOS)
        // On iPhone the software keyboard covers half the screen; give it an explicit dismiss button.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { isEditorFocused = false }
                    .fontWeight(.semibold)
            }
        }
        #endif
    }

    private var isCompact: Bool { horizontalSizeClass == .compact }

    /// Phones get a shorter math panel so the editor keeps a usable number of lines.
    private var formulaPanelHeight: CGFloat {
        isCompact ? 190 : 230
    }

    // MARK: - Header

    private var header: some View {
        @Bindable var model = appModel
        return HStack {
            Label("CalligramScript", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Menu {
                ForEach(CalligramSampleCategory.allCases) { category in
                    Section(category.rawValue) {
                        ForEach(CalligramSamples.samples(in: category)) { sample in
                            Button(sample.title) {
                                appModel.loadSample(sample)
                            }
                        }
                    }
                }
            } label: {
                Label("샘플", systemImage: "doc.text")
            }
            .menuStyle(.button)
            Toggle(isOn: $model.isFormulaPanelVisible) {
                Label("수식", systemImage: "function")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .help("코드를 수학 수식으로 표시")
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

    // MARK: - Math notation

    /// Shows the current program rewritten as mathematical notation. Updates after every run.
    private var formulaPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "function")
                    .foregroundStyle(.secondary)
                Text("수식 표현")
                    .font(.subheadline.weight(.semibold))
                if !isCompact {
                    Text("코드 → 수학 표기 자동 변환")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                if !isCompact, let summary = appModel.activeSampleSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(summary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Phones are too narrow for the summary in the header; give it its own line.
            if isCompact, let summary = appModel.activeSampleSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }

            ScrollView([.vertical, .horizontal]) {
                Text(appModel.formulaText.isEmpty ? "실행하면 수식이 여기에 표시됩니다." : appModel.formulaText)
                    .font(.system(size: 13, design: .serif))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            Text("P 글리프 위치 · C 색(RGB/HSV) · s 글리프 크기 · ∀ i ∈ {…} 반복 · U(a, b) 균등 난수 · ← 갱신")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(isCompact ? 2 : 1)
                .truncationMode(.tail)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
        }
        .frame(height: formulaPanelHeight)
        .background(Color.black.opacity(0.1))
    }
}

#Preview {
    CodeEditorView()
        .environment(AppModel())
        .frame(width: 520, height: 620)
}
