import Foundation
import simd

/// A runtime value in CalligramScript.
nonisolated enum CalligramValue: Sendable, Equatable {
    case number(Double)
    case boolean(Bool)
    case string(String)

    var typeName: String {
        switch self {
        case .number: return "숫자"
        case .boolean: return "불"
        case .string: return "문자열"
        }
    }
}

/// One glyph placed in 3D space by an `emit` call.
nonisolated struct CalligramPoint: Sendable {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
    var size: Float
    var glyph: Character
}

nonisolated enum DiagnosticSeverity: Sendable, Hashable {
    case error
    case warning
    case info
}

nonisolated struct CalligramDiagnostic: Sendable, Identifiable, Hashable {
    let id = UUID()
    var severity: DiagnosticSeverity
    var message: String
    var location: SourceLocation

    var locationText: String {
        location.line > 0 ? "\(location.line):\(location.column)" : "-"
    }
}

/// Result of running a program: the emitted glyphs plus execution statistics.
nonisolated struct CalligramProgramOutput: Sendable {
    var points: [CalligramPoint]
    var stepCount: Int
    var duration: TimeInterval
}

nonisolated struct CalligramLimits: Sendable {
    var maxEmits = 15_000
    var maxSteps = 500_000
}

/// Tree-walking interpreter for CalligramScript.
nonisolated struct CalligramInterpreter {
    struct RunResult: Sendable {
        var output: CalligramProgramOutput
        var diagnostics: [CalligramDiagnostic]
    }

    private struct Slot {
        var value: CalligramValue
        var isConstant: Bool
    }

    private let limits: CalligramLimits
    private var scopes: [[String: Slot]] = [[:]]
    private var points: [CalligramPoint] = []
    private var diagnostics: [CalligramDiagnostic] = []
    private var stepCount = 0
    private var skippedEmits = 0

    // Drawing state
    private var currentColor = SIMD4<Float>(0.55, 0.85, 1.0, 1.0)
    private var currentSize: Float = 0.022

    // Glyph streams: the source code itself, or an override set by `glyph("...")`.
    private let sourceGlyphs: [Character]
    private var sourceGlyphIndex = 0
    private var overrideGlyphs: [Character]?
    private var overrideGlyphIndex = 0

    // Deterministic random generator so the same code always produces the same shape.
    private var randomState: UInt64 = 0x9E37_79B9_7F4A_7C15

    init(source: String, limits: CalligramLimits = CalligramLimits()) {
        self.limits = limits
        let glyphs = source.filter { !$0.isWhitespace && !$0.isNewline }
        sourceGlyphs = glyphs.isEmpty ? Array("CODE") : Array(glyphs)
    }

    // MARK: - Entry point

    mutating func run(_ statements: [Statement]) -> RunResult {
        let start = Date()
        do {
            try execute(statements)
        } catch let error as CalligramError {
            diagnostics.append(CalligramDiagnostic(severity: .error, message: error.message, location: error.location))
        } catch {
            diagnostics.append(CalligramDiagnostic(severity: .error, message: error.localizedDescription, location: .unknown))
        }
        if skippedEmits > 0 {
            diagnostics.append(CalligramDiagnostic(
                severity: .warning,
                message: "유한하지 않은 좌표(NaN/무한) 때문에 emit \(skippedEmits)개를 건너뛰었습니다.",
                location: .unknown))
        }
        if points.isEmpty && !diagnostics.contains(where: { $0.severity == .error }) {
            diagnostics.append(CalligramDiagnostic(
                severity: .info,
                message: "emit()가 호출되지 않아 표시할 글리프가 없습니다.",
                location: .unknown))
        }
        let output = CalligramProgramOutput(points: points, stepCount: stepCount, duration: Date().timeIntervalSince(start))
        return RunResult(output: output, diagnostics: diagnostics)
    }

    // MARK: - Statements

    private mutating func execute(_ statements: [Statement]) throws {
        for statement in statements {
            try execute(statement)
        }
    }

    private mutating func execute(_ statement: Statement) throws {
        try countStep(at: statementLocation(statement))
        switch statement {
        case .declaration(let name, let isConstant, let valueExpression, let location):
            let value = try evaluate(valueExpression)
            try declare(name, value: value, isConstant: isConstant, at: location)

        case .assignment(let name, let symbol, let valueExpression, let location):
            let rhs = try evaluate(valueExpression)
            let newValue: CalligramValue
            if symbol == .assign {
                newValue = rhs
            } else {
                let existing = try lookup(name, at: location)
                let binaryOperator: Symbol
                switch symbol {
                case .plusAssign: binaryOperator = .plus
                case .minusAssign: binaryOperator = .minus
                case .starAssign: binaryOperator = .star
                default: binaryOperator = .slash
                }
                newValue = try applyBinary(binaryOperator, existing, rhs, at: location)
            }
            try assign(name, value: newValue, at: location)

        case .forLoop(let variable, let startExpression, let endExpression, let isInclusive, let body, let location):
            let start = try number(from: try evaluate(startExpression), context: "for 시작값", at: location)
            let end = try number(from: try evaluate(endExpression), context: "for 끝값", at: location)
            guard start.isFinite, end.isFinite else {
                throw CalligramError(message: "반복 범위가 유한하지 않습니다.", location: location)
            }
            let iterations = isInclusive ? (end - start + 1) : (end - start)
            if iterations > Double(limits.maxSteps) {
                throw CalligramError(message: "반복 횟수(\(Int(iterations)))가 한도(\(limits.maxSteps))를 넘습니다.", location: location)
            }
            var counter = start
            while isInclusive ? (counter <= end) : (counter < end) {
                try countStep(at: location)
                scopes.append([variable: Slot(value: .number(counter), isConstant: true)])
                defer { scopes.removeLast() }
                try execute(body)
                counter += 1
            }

        case .conditional(let conditionExpression, let thenBody, let elseBody, let location):
            let condition = try evaluate(conditionExpression)
            guard case .boolean(let flag) = condition else {
                throw CalligramError(message: "if 조건은 불(true/false)이어야 합니다. (받은 타입: \(condition.typeName))", location: location)
            }
            scopes.append([:])
            defer { scopes.removeLast() }
            if flag {
                try execute(thenBody)
            } else if let elseBody {
                try execute(elseBody)
            }

        case .expression(let expression, _):
            _ = try evaluate(expression)
        }
    }

    private func statementLocation(_ statement: Statement) -> SourceLocation {
        switch statement {
        case .declaration(_, _, _, let location), .assignment(_, _, _, let location),
             .forLoop(_, _, _, _, _, let location), .conditional(_, _, _, let location),
             .expression(_, let location):
            return location
        }
    }

    private mutating func countStep(at location: SourceLocation) throws {
        stepCount += 1
        if stepCount > limits.maxSteps {
            throw CalligramError(message: "실행 스텝이 한도(\(limits.maxSteps))를 넘었습니다. 반복 횟수를 줄여 주세요.", location: location)
        }
    }

    // MARK: - Scopes

    private mutating func declare(_ name: String, value: CalligramValue, isConstant: Bool, at location: SourceLocation) throws {
        if scopes[scopes.count - 1][name] != nil {
            throw CalligramError(message: "'\(name)'은(는) 같은 범위에서 이미 선언되었습니다.", location: location)
        }
        scopes[scopes.count - 1][name] = Slot(value: value, isConstant: isConstant)
    }

    private func lookup(_ name: String, at location: SourceLocation) throws -> CalligramValue {
        for scope in scopes.reversed() {
            if let slot = scope[name] { return slot.value }
        }
        if let constant = Self.constants[name] { return .number(constant) }
        throw CalligramError(message: "정의되지 않은 변수 '\(name)'", location: location)
    }

    private mutating func assign(_ name: String, value: CalligramValue, at location: SourceLocation) throws {
        for scopeIndex in stride(from: scopes.count - 1, through: 0, by: -1) {
            if let slot = scopes[scopeIndex][name] {
                if slot.isConstant {
                    throw CalligramError(message: "'\(name)'은(는) let 상수이므로 바꿀 수 없습니다. var로 선언하세요.", location: location)
                }
                scopes[scopeIndex][name] = Slot(value: value, isConstant: false)
                return
            }
        }
        throw CalligramError(message: "정의되지 않은 변수 '\(name)'에 대입할 수 없습니다. 먼저 var로 선언하세요.", location: location)
    }

    private static let constants: [String: Double] = [
        "PI": Double.pi,
        "TAU": Double.pi * 2,
        "E": M_E,
    ]

    // MARK: - Expressions

    private mutating func evaluate(_ expression: Expression) throws -> CalligramValue {
        switch expression {
        case .number(let value, _):
            return .number(value)
        case .string(let value, _):
            return .string(value)
        case .boolean(let value, _):
            return .boolean(value)
        case .identifier(let name, let location):
            return try lookup(name, at: location)
        case .unary(let symbol, let operandExpression, let location):
            let operand = try evaluate(operandExpression)
            switch (symbol, operand) {
            case (.minus, .number(let value)):
                return .number(-value)
            case (.not, .boolean(let flag)):
                return .boolean(!flag)
            default:
                throw CalligramError(message: "'\(symbol.rawValue)'를 \(operand.typeName)에 적용할 수 없습니다.", location: location)
            }
        case .binary(let symbol, let lhsExpression, let rhsExpression, let location):
            // Short-circuit logical operators.
            if symbol == .and || symbol == .or {
                let lhs = try evaluate(lhsExpression)
                guard case .boolean(let lhsFlag) = lhs else {
                    throw CalligramError(message: "'\(symbol.rawValue)'의 왼쪽은 불이어야 합니다.", location: location)
                }
                if symbol == .and && !lhsFlag { return .boolean(false) }
                if symbol == .or && lhsFlag { return .boolean(true) }
                let rhs = try evaluate(rhsExpression)
                guard case .boolean(let rhsFlag) = rhs else {
                    throw CalligramError(message: "'\(symbol.rawValue)'의 오른쪽은 불이어야 합니다.", location: location)
                }
                return .boolean(rhsFlag)
            }
            let lhs = try evaluate(lhsExpression)
            let rhs = try evaluate(rhsExpression)
            return try applyBinary(symbol, lhs, rhs, at: location)
        case .call(let name, let argumentExpressions, let location):
            var arguments: [CalligramValue] = []
            arguments.reserveCapacity(argumentExpressions.count)
            for argumentExpression in argumentExpressions {
                arguments.append(try evaluate(argumentExpression))
            }
            return try call(name, arguments, at: location)
        }
    }

    private func applyBinary(_ symbol: Symbol, _ lhs: CalligramValue, _ rhs: CalligramValue, at location: SourceLocation) throws -> CalligramValue {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)):
            switch symbol {
            case .plus: return .number(a + b)
            case .minus: return .number(a - b)
            case .star: return .number(a * b)
            case .slash: return .number(a / b)
            case .percent: return .number(b == 0 ? .nan : a.truncatingRemainder(dividingBy: b))
            case .caret: return .number(pow(a, b))
            case .equal: return .boolean(a == b)
            case .notEqual: return .boolean(a != b)
            case .less: return .boolean(a < b)
            case .lessEqual: return .boolean(a <= b)
            case .greater: return .boolean(a > b)
            case .greaterEqual: return .boolean(a >= b)
            default: break
            }
        case (.boolean(let a), .boolean(let b)):
            switch symbol {
            case .equal: return .boolean(a == b)
            case .notEqual: return .boolean(a != b)
            default: break
            }
        case (.string(let a), .string(let b)):
            switch symbol {
            case .plus: return .string(a + b)
            case .equal: return .boolean(a == b)
            case .notEqual: return .boolean(a != b)
            default: break
            }
        default:
            break
        }
        throw CalligramError(message: "'\(symbol.rawValue)'를 \(lhs.typeName)과(와) \(rhs.typeName)에 적용할 수 없습니다.", location: location)
    }

    // MARK: - Built-in functions

    private mutating func call(_ name: String, _ arguments: [CalligramValue], at location: SourceLocation) throws -> CalligramValue {
        switch name {
        // Scene side effects
        case "emit":
            try expectCount(arguments, 3, name, at: location)
            let x = try number(from: arguments[0], context: "emit x", at: location)
            let y = try number(from: arguments[1], context: "emit y", at: location)
            let z = try number(from: arguments[2], context: "emit z", at: location)
            try emit(x: x, y: y, z: z, at: location)
            return .boolean(true)

        case "color":
            guard arguments.count == 3 || arguments.count == 4 else {
                throw CalligramError(message: "color(r, g, b[, a])는 3개 또는 4개의 인자가 필요합니다.", location: location)
            }
            let r = try unitNumber(from: arguments[0], context: "color r", at: location)
            let g = try unitNumber(from: arguments[1], context: "color g", at: location)
            let b = try unitNumber(from: arguments[2], context: "color b", at: location)
            let a = arguments.count == 4 ? try unitNumber(from: arguments[3], context: "color a", at: location) : 1
            currentColor = SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
            return .boolean(true)

        case "hsv":
            try expectCount(arguments, 3, name, at: location)
            let h = try number(from: arguments[0], context: "hsv h", at: location)
            let s = try unitNumber(from: arguments[1], context: "hsv s", at: location)
            let v = try unitNumber(from: arguments[2], context: "hsv v", at: location)
            let rgb = Self.hsvToRGB(h: h, s: s, v: v)
            currentColor = SIMD4<Float>(Float(rgb.0), Float(rgb.1), Float(rgb.2), currentColor.w)
            return .boolean(true)

        case "size":
            try expectCount(arguments, 1, name, at: location)
            let size = try number(from: arguments[0], context: "size", at: location)
            guard size.isFinite, size > 0 else {
                throw CalligramError(message: "size는 0보다 큰 유한한 값이어야 합니다.", location: location)
            }
            currentSize = Float(min(size, 2.0))
            return .boolean(true)

        case "glyph":
            try expectCount(arguments, 1, name, at: location)
            guard case .string(let text) = arguments[0] else {
                throw CalligramError(message: "glyph()는 문자열 인자가 필요합니다. 예: glyph(\"*+\")", location: location)
            }
            let glyphs = text.filter { !$0.isWhitespace }
            overrideGlyphs = glyphs.isEmpty ? nil : Array(glyphs)
            overrideGlyphIndex = 0
            return .boolean(true)

        case "seed":
            try expectCount(arguments, 1, name, at: location)
            let seed = try number(from: arguments[0], context: "seed", at: location)
            randomState = UInt64(truncatingIfNeeded: Int64(seed.isFinite ? seed : 0)) &+ 0x9E37_79B9_7F4A_7C15
            return .boolean(true)

        case "random":
            if arguments.isEmpty { return .number(nextRandom()) }
            try expectCount(arguments, 2, name, at: location)
            let low = try number(from: arguments[0], context: "random 최소", at: location)
            let high = try number(from: arguments[1], context: "random 최대", at: location)
            return .number(low + (high - low) * nextRandom())

        // Pure math
        case "sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "abs", "floor", "ceil", "round", "exp", "log", "log2", "sign":
            try expectCount(arguments, 1, name, at: location)
            let x = try number(from: arguments[0], context: name, at: location)
            switch name {
            case "sin": return .number(sin(x))
            case "cos": return .number(cos(x))
            case "tan": return .number(tan(x))
            case "asin": return .number(asin(x))
            case "acos": return .number(acos(x))
            case "atan": return .number(atan(x))
            case "sqrt": return .number(sqrt(x))
            case "abs": return .number(abs(x))
            case "floor": return .number(floor(x))
            case "ceil": return .number(ceil(x))
            case "round": return .number(x.rounded())
            case "exp": return .number(exp(x))
            case "log": return .number(log(x))
            case "log2": return .number(log2(x))
            default: return .number(x > 0 ? 1 : (x < 0 ? -1 : 0))
            }

        case "atan2", "pow", "min", "max", "hypot":
            try expectCount(arguments, 2, name, at: location)
            let a = try number(from: arguments[0], context: name, at: location)
            let b = try number(from: arguments[1], context: name, at: location)
            switch name {
            case "atan2": return .number(atan2(a, b))
            case "pow": return .number(pow(a, b))
            case "min": return .number(min(a, b))
            case "max": return .number(max(a, b))
            default: return .number(hypot(a, b))
            }

        case "clamp", "lerp":
            try expectCount(arguments, 3, name, at: location)
            let a = try number(from: arguments[0], context: name, at: location)
            let b = try number(from: arguments[1], context: name, at: location)
            let c = try number(from: arguments[2], context: name, at: location)
            if name == "clamp" { return .number(min(max(a, b), c)) }
            return .number(a + (b - a) * c)

        default:
            throw CalligramError(message: "알 수 없는 함수 '\(name)'. 사용 가능: emit, color, hsv, size, glyph, sin, cos, sqrt, ...", location: location)
        }
    }

    private mutating func emit(x: Double, y: Double, z: Double, at location: SourceLocation) throws {
        guard x.isFinite, y.isFinite, z.isFinite else {
            skippedEmits += 1
            return
        }
        if points.count >= limits.maxEmits {
            throw CalligramError(message: "emit 한도(\(limits.maxEmits)개)에 도달했습니다. 점 개수를 줄여 주세요.", location: location)
        }
        let glyph = nextGlyph()
        points.append(CalligramPoint(position: SIMD3<Float>(Float(x), Float(y), Float(z)),
                                     color: currentColor,
                                     size: currentSize,
                                     glyph: glyph))
    }

    private mutating func nextGlyph() -> Character {
        if let overrideGlyphs {
            let glyph = overrideGlyphs[overrideGlyphIndex % overrideGlyphs.count]
            overrideGlyphIndex += 1
            return glyph
        }
        let glyph = sourceGlyphs[sourceGlyphIndex % sourceGlyphs.count]
        sourceGlyphIndex += 1
        return glyph
    }

    /// SplitMix64: fast, deterministic, good enough for art.
    private mutating func nextRandom() -> Double {
        randomState &+= 0x9E37_79B9_7F4A_7C15
        var z = randomState
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }

    private static func hsvToRGB(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let hue = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let sector = Int(floor(hue)) % 6
        let f = hue - floor(hue)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        switch sector {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    // MARK: - Argument helpers

    private func expectCount(_ arguments: [CalligramValue], _ count: Int, _ name: String, at location: SourceLocation) throws {
        guard arguments.count == count else {
            throw CalligramError(message: "\(name)()는 인자 \(count)개가 필요합니다. (받은 개수: \(arguments.count))", location: location)
        }
    }

    private func number(from value: CalligramValue, context: String, at location: SourceLocation) throws -> Double {
        guard case .number(let number) = value else {
            throw CalligramError(message: "\(context)에는 숫자가 필요합니다. (받은 타입: \(value.typeName))", location: location)
        }
        return number
    }

    private func unitNumber(from value: CalligramValue, context: String, at location: SourceLocation) throws -> Double {
        let number = try number(from: value, context: context, at: location)
        return number.isFinite ? min(max(number, 0), 1) : 0
    }
}
