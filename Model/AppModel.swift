import Foundation
import Observation

/// Central observable state shared by the editor window and the immersive space.
@Observable
@MainActor
final class AppModel {
    static let immersiveSpaceID = "CalligramSpace"

    enum ImmersiveState {
        case closed
        case inTransition
        case open
    }

    // MARK: - Editor state

    var source: String = CalligramSamples.helix.source {
        didSet {
            guard source != oldValue else { return }
            if isLivePreviewEnabled { scheduleLiveRun() }
        }
    }

    var isLivePreviewEnabled = true {
        didSet {
            if isLivePreviewEnabled { scheduleLiveRun() }
        }
    }

    // MARK: - Program results

    private(set) var output: CalligramProgramOutput?
    private(set) var diagnostics: [CalligramDiagnostic] = []
    private(set) var isRunning = false

    /// Increments whenever the rendered scene must be rebuilt (new output or new settings).
    private(set) var revision = 0

    var settings = CalligramRenderSettings() {
        didSet {
            guard settings != oldValue else { return }
            revision += 1
        }
    }

    var immersiveState: ImmersiveState = .closed

    private var liveRunTask: Task<Void, Never>?

    // MARK: - Derived

    var glyphCount: Int { output?.points.count ?? 0 }

    var statusText: String {
        if isRunning { return "실행 중…" }
        guard let output else {
            return diagnostics.isEmpty ? "실행 대기" : "오류 — 마지막 성공 결과 유지"
        }
        let milliseconds = Int((output.duration * 1000).rounded())
        return "글리프 \(output.points.count.formatted())개 · 스텝 \(output.stepCount.formatted()) · \(milliseconds) ms"
    }

    var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }

    // MARK: - Actions

    func loadSample(_ sample: CalligramSample) {
        source = sample.source
        if !isLivePreviewEnabled {
            Task { await run() }
        }
    }

    /// Debounced run used by live preview. Cancels any pending run from earlier keystrokes.
    func scheduleLiveRun() {
        liveRunTask?.cancel()
        liveRunTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            await self.run()
        }
    }

    /// Compiles and runs the current source off the main actor, then publishes the result.
    func run() async {
        isRunning = true
        let currentSource = source
        let result = await Task.detached(priority: .userInitiated) {
            CalligramEngine.run(source: currentSource)
        }.value
        guard !Task.isCancelled else {
            isRunning = false
            return
        }
        diagnostics = result.diagnostics
        // Keep the previous shape visible when the new program fails to parse.
        if let newOutput = result.output {
            output = newOutput
            revision += 1
        }
        isRunning = false
    }

    /// Runs the initial program once when the UI first appears.
    func runIfNeeded() async {
        guard output == nil, !isRunning else { return }
        await run()
    }
}
