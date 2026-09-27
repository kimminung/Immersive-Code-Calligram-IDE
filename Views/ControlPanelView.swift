import SwiftUI

/// Render options, execution status, and diagnostics for the current program.
struct ControlPanelView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var model = appModel
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                #if os(visionOS)
                ImmersiveToggleButton()
                Divider()
                #endif

                section("실행") {
                    Toggle("라이브 프리뷰", isOn: $model.isLivePreviewEnabled)
                    HStack {
                        if appModel.isRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: appModel.hasErrors ? "xmark.octagon.fill" : "checkmark.circle.fill")
                                .foregroundStyle(appModel.hasErrors ? .red : .green)
                        }
                        Text(appModel.statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                section("글리프") {
                    LabeledContent("크기 배율") {
                        Text(appModel.settings.glyphScale.formatted(.number.precision(.fractionLength(1))) + "×")
                            .monospacedDigit()
                    }
                    Slider(value: $model.settings.glyphScale, in: 0.4...3.0, step: 0.1)
                    Picker("방향", selection: $model.settings.facing) {
                        ForEach(GlyphFacing.allCases) { facing in
                            Text(facing.title).tag(facing)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("자동 회전", isOn: $model.settings.isSpinning)
                }

                section("진단") {
                    if appModel.diagnostics.isEmpty {
                        Text("문제 없음")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appModel.diagnostics) { diagnostic in
                            DiagnosticRow(diagnostic: diagnostic)
                        }
                    }
                }

                section("언어 요약") {
                    Text(languageCheatSheet)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(14)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var languageCheatSheet: String {
        """
        let x = 1      var y = 2
        for i in 0..<n { ... }
        if a < b { } else { }
        emit(x, y, z)
        color(r, g, b[, a])  hsv(h, s, v)
        size(m)  glyph("text")
        sin cos tan sqrt abs pow min max
        floor ceil round exp log atan2
        clamp(x, lo, hi) lerp(a, b, t)
        random() random(a, b) seed(n)
        PI TAU E
        """
    }
}

private struct DiagnosticRow: View {
    let diagnostic: CalligramDiagnostic

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.locationText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(diagnostic.message)
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .background(iconColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch diagnostic.severity {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch diagnostic.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

#Preview {
    ControlPanelView()
        .environment(AppModel())
        .frame(width: 320, height: 600)
}
