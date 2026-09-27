import Foundation

/// Result of compiling and running a CalligramScript program.
nonisolated struct CalligramRunResult: Sendable {
    /// `nil` when the program failed to parse. Runtime errors still return a partial output.
    var output: CalligramProgramOutput?
    var diagnostics: [CalligramDiagnostic]

    var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}

/// Facade that runs the whole pipeline: lex → parse → interpret.
/// Safe to call from any isolation domain; all types involved are `Sendable`.
nonisolated enum CalligramEngine {
    static func run(source: String, limits: CalligramLimits = CalligramLimits()) -> CalligramRunResult {
        let statements: [Statement]
        do {
            statements = try CalligramParser.parse(source)
        } catch let error as CalligramError {
            return CalligramRunResult(
                output: nil,
                diagnostics: [CalligramDiagnostic(severity: .error, message: error.message, location: error.location)])
        } catch {
            return CalligramRunResult(
                output: nil,
                diagnostics: [CalligramDiagnostic(severity: .error, message: error.localizedDescription, location: .unknown)])
        }

        var interpreter = CalligramInterpreter(source: source, limits: limits)
        let result = interpreter.run(statements)
        return CalligramRunResult(output: result.output, diagnostics: result.diagnostics)
    }
}
