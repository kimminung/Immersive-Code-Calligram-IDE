import Foundation

/// Expression nodes of CalligramScript.
nonisolated indirect enum Expression: Sendable {
    case number(Double, SourceLocation)
    case string(String, SourceLocation)
    case boolean(Bool, SourceLocation)
    case identifier(String, SourceLocation)
    case unary(operator: Symbol, operand: Expression, SourceLocation)
    case binary(operator: Symbol, lhs: Expression, rhs: Expression, SourceLocation)
    case call(name: String, arguments: [Expression], SourceLocation)

    var location: SourceLocation {
        switch self {
        case .number(_, let location), .string(_, let location), .boolean(_, let location),
             .identifier(_, let location), .unary(_, _, let location), .binary(_, _, _, let location),
             .call(_, _, let location):
            return location
        }
    }
}

/// Statement nodes of CalligramScript.
nonisolated indirect enum Statement: Sendable {
    case declaration(name: String, isConstant: Bool, value: Expression, SourceLocation)
    case assignment(name: String, operator: Symbol, value: Expression, SourceLocation)
    case forLoop(variable: String, start: Expression, end: Expression, isInclusive: Bool, body: [Statement], SourceLocation)
    case conditional(condition: Expression, thenBody: [Statement], elseBody: [Statement]?, SourceLocation)
    case expression(Expression, SourceLocation)
}
