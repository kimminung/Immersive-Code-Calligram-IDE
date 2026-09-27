import Foundation

/// Pretty-prints a CalligramScript AST as mathematical notation (Unicode text).
///
/// The output is meant to be read, not parsed: loops become `∀ i ∈ {0, …, n−1}`,
/// `emit` becomes a point definition `P ← (x, y, z)`, `sqrt` becomes `√`, powers use
/// superscripts, and constants such as `PI` become `π`.
nonisolated enum CalligramMathFormatter {
    static func format(_ statements: [Statement]) -> String {
        var printer = Printer()
        printer.print(statements)
        return printer.lines.joined(separator: "\n")
    }

    /// Convenience used by callers that only have source text. Returns `nil` when parsing fails.
    static func format(source: String) -> String? {
        guard let statements = try? CalligramParser.parse(source) else { return nil }
        return format(statements)
    }

    // MARK: - Precedence

    /// Operator precedence, from loosest to tightest binding. Used to re-insert parentheses,
    /// because the parser drops explicit grouping from the AST.
    private enum Precedence: Int, Comparable {
        case or = 1, and, equality, comparison, additive, multiplicative, unary, power, atom

        static func < (lhs: Precedence, rhs: Precedence) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private struct Rendered {
        var text: String
        var precedence: Precedence

        /// Wraps in parentheses when this term binds looser than `required`.
        func wrapped(below required: Precedence) -> String {
            precedence < required ? "(" + text + ")" : text
        }

        /// Wraps in parentheses when this term binds looser than or equal to `required`.
        func wrapped(atOrBelow required: Precedence) -> String {
            precedence <= required ? "(" + text + ")" : text
        }
    }

    // MARK: - Statement printer

    private struct Printer {
        var lines: [String] = []
        private var depth = 0

        private var indent: String { String(repeating: "    ", count: depth) }

        mutating func print(_ statements: [Statement]) {
            for statement in statements { print(statement) }
        }

        private mutating func emitLine(_ text: String) {
            lines.append(indent + text)
        }

        private mutating func print(_ statement: Statement) {
            switch statement {
            case .declaration(let name, _, let value, _):
                emitLine("\(symbol(name)) = \(render(value).text)")

            case .assignment(let name, let symbolKind, let value, _):
                let target = symbol(name)
                let rhs = render(value)
                switch symbolKind {
                case .plusAssign: emitLine("\(target) ← \(target) + \(rhs.wrapped(below: .additive))")
                case .minusAssign: emitLine("\(target) ← \(target) − \(rhs.wrapped(atOrBelow: .additive))")
                case .starAssign: emitLine("\(target) ← \(target) · \(rhs.wrapped(below: .multiplicative))")
                case .slashAssign: emitLine("\(target) ← \(target) / \(rhs.wrapped(atOrBelow: .multiplicative))")
                default: emitLine("\(target) ← \(rhs.text)")
                }

            case .forLoop(let variable, let start, let end, let isInclusive, let body, _):
                let lower = render(start).text
                let upper = isInclusive ? render(end).text : lastIndex(before: end)
                emitLine("∀ \(symbol(variable)) ∈ {\(lower), …, \(upper)}:")
                depth += 1
                print(body)
                depth -= 1

            case .conditional(let condition, let thenBody, let elseBody, _):
                emitLine("if \(render(condition).text):")
                depth += 1
                print(thenBody)
                depth -= 1
                if let elseBody {
                    if elseBody.count == 1, case .conditional = elseBody[0] {
                        // else-if chain: print as "otherwise if …" on one level.
                        emitLine("otherwise,")
                        print(elseBody)
                    } else {
                        emitLine("otherwise:")
                        depth += 1
                        print(elseBody)
                        depth -= 1
                    }
                }

            case .expression(let expression, _):
                emitLine(renderStatementExpression(expression))
            }
        }

        /// `n − 1` for the half-open range `0..<n`, folding literals.
        private func lastIndex(before end: Expression) -> String {
            if case .number(let value, _) = end {
                return formatNumber(value - 1)
            }
            let rendered = render(end)
            return rendered.wrapped(below: .additive) + " − 1"
        }

        /// Scene side effects read better as definitions than as function calls.
        private func renderStatementExpression(_ expression: Expression) -> String {
            guard case .call(let name, let arguments, _) = expression else {
                return render(expression).text
            }
            let args = arguments.map { render($0).text }
            switch (name, args.count) {
            case ("emit", 3):
                return "P ← (\(args[0]), \(args[1]), \(args[2]))"
            case ("color", 3):
                return "C ← (\(args[0]), \(args[1]), \(args[2]))ᴿᴳᴮ"
            case ("color", 4):
                return "C ← (\(args[0]), \(args[1]), \(args[2]), \(args[3]))ᴿᴳᴮᴬ"
            case ("hsv", 3):
                return "C ← HSV(\(args[0]), \(args[1]), \(args[2]))"
            case ("size", 1):
                return "s ← \(args[0])"
            case ("glyph", 1):
                return "glyphs ← \(args[0])"
            case ("seed", 1):
                return "seed ← \(args[0])"
            default:
                return render(expression).text
            }
        }
    }

    // MARK: - Expressions

    private static func render(_ expression: Expression) -> Rendered {
        switch expression {
        case .number(let value, _):
            return Rendered(text: formatNumber(value), precedence: value < 0 ? .unary : .atom)

        case .string(let value, _):
            return Rendered(text: "“\(value)”", precedence: .atom)

        case .boolean(let value, _):
            return Rendered(text: value ? "true" : "false", precedence: .atom)

        case .identifier(let name, _):
            switch name {
            case "PI": return Rendered(text: "π", precedence: .atom)
            case "TAU": return Rendered(text: "2π", precedence: .multiplicative)
            case "E": return Rendered(text: "e", precedence: .atom)
            default: return Rendered(text: symbol(name), precedence: .atom)
            }

        case .unary(let op, let operand, _):
            let inner = render(operand)
            switch op {
            case .not:
                return Rendered(text: "¬" + inner.wrapped(below: .unary), precedence: .unary)
            default:
                return Rendered(text: "−" + inner.wrapped(below: .unary), precedence: .unary)
            }

        case .binary(let op, let lhs, let rhs, _):
            return renderBinary(op, lhs, rhs)

        case .call(let name, let arguments, _):
            return renderCall(name, arguments)
        }
    }

    private static func renderBinary(_ op: Symbol, _ lhsExpression: Expression, _ rhsExpression: Expression) -> Rendered {
        let lhs = render(lhsExpression)
        let rhs = render(rhsExpression)

        switch op {
        case .plus:
            return Rendered(text: "\(lhs.wrapped(below: .additive)) + \(rhs.wrapped(below: .additive))", precedence: .additive)
        case .minus:
            return Rendered(text: "\(lhs.wrapped(below: .additive)) − \(rhs.wrapped(atOrBelow: .additive))", precedence: .additive)

        case .star:
            let left = lhs.wrapped(below: .multiplicative)
            let right = rhs.wrapped(below: .multiplicative)
            // "2x", "0.5 sin(t)": a numeric coefficient is juxtaposed with the term it scales.
            if case .number(let value, _) = lhsExpression, value >= 0, isJuxtaposable(rhsExpression) {
                let separator = startsWithLetterOrSymbol(right) && !isCall(rhsExpression) ? "" : " "
                return Rendered(text: left + separator + right, precedence: .multiplicative)
            }
            return Rendered(text: "\(left) · \(right)", precedence: .multiplicative)

        case .slash:
            if lhs.precedence == .atom && rhs.precedence == .atom {
                return Rendered(text: "\(lhs.text)/\(rhs.text)", precedence: .multiplicative)
            }
            return Rendered(text: "\(lhs.wrapped(below: .multiplicative)) / \(rhs.wrapped(atOrBelow: .multiplicative))",
                            precedence: .multiplicative)

        case .percent:
            return Rendered(text: "\(lhs.wrapped(below: .multiplicative)) mod \(rhs.wrapped(atOrBelow: .multiplicative))",
                            precedence: .multiplicative)

        case .caret:
            return renderPower(base: lhs, exponent: rhsExpression)

        case .equal: return comparison(lhs, "=", rhs, .equality)
        case .notEqual: return comparison(lhs, "≠", rhs, .equality)
        case .less: return comparison(lhs, "<", rhs, .comparison)
        case .lessEqual: return comparison(lhs, "≤", rhs, .comparison)
        case .greater: return comparison(lhs, ">", rhs, .comparison)
        case .greaterEqual: return comparison(lhs, "≥", rhs, .comparison)

        case .and:
            return Rendered(text: "\(lhs.wrapped(below: .and)) ∧ \(rhs.wrapped(below: .and))", precedence: .and)
        case .or:
            return Rendered(text: "\(lhs.wrapped(below: .or)) ∨ \(rhs.wrapped(below: .or))", precedence: .or)

        default:
            return Rendered(text: "\(lhs.text) \(op.rawValue) \(rhs.text)", precedence: .atom)
        }
    }

    private static func comparison(_ lhs: Rendered, _ sign: String, _ rhs: Rendered, _ precedence: Precedence) -> Rendered {
        Rendered(text: "\(lhs.wrapped(atOrBelow: precedence)) \(sign) \(rhs.wrapped(atOrBelow: precedence))", precedence: precedence)
    }

    /// `x²` when the exponent is a small integer literal, otherwise `x^(expr)`.
    private static func renderPower(base: Rendered, exponent: Expression) -> Rendered {
        let baseText = base.wrapped(below: .power)
        if case .number(let value, _) = exponent, let superscript = superscriptInteger(value) {
            return Rendered(text: baseText + superscript, precedence: .power)
        }
        let exp = render(exponent)
        let expText = exp.precedence == .atom ? exp.text : "(" + exp.text + ")"
        return Rendered(text: baseText + "^" + expText, precedence: .power)
    }

    private static func renderCall(_ name: String, _ arguments: [Expression]) -> Rendered {
        let rendered = arguments.map { render($0) }
        let args = rendered.map(\.text)
        func first() -> String { args.first ?? "" }

        switch (name, args.count) {
        case ("sqrt", 1):
            let inner = rendered[0]
            return Rendered(text: inner.precedence == .atom ? "√" + inner.text : "√(" + inner.text + ")", precedence: .atom)
        case ("abs", 1):
            return Rendered(text: "|\(first())|", precedence: .atom)
        case ("floor", 1):
            return Rendered(text: "⌊\(first())⌋", precedence: .atom)
        case ("ceil", 1):
            return Rendered(text: "⌈\(first())⌉", precedence: .atom)
        case ("round", 1):
            return Rendered(text: "⌊\(first())⌉", precedence: .atom)
        case ("fract", 1):
            return Rendered(text: "frac(\(first()))", precedence: .atom)
        case ("exp", 1):
            let inner = rendered[0]
            let expText = inner.precedence == .atom ? inner.text : "(" + inner.text + ")"
            return Rendered(text: "e^" + expText, precedence: .power)
        case ("log", 1):
            return Rendered(text: "ln(\(first()))", precedence: .atom)
        case ("log2", 1):
            return Rendered(text: "log₂(\(first()))", precedence: .atom)
        case ("sign", 1):
            return Rendered(text: "sgn(\(first()))", precedence: .atom)
        case ("asin", 1):
            return Rendered(text: "sin⁻¹(\(first()))", precedence: .atom)
        case ("acos", 1):
            return Rendered(text: "cos⁻¹(\(first()))", precedence: .atom)
        case ("atan", 1):
            return Rendered(text: "tan⁻¹(\(first()))", precedence: .atom)
        case ("pow", 2):
            return renderPower(base: rendered[0], exponent: arguments[1])
        case ("hypot", 2):
            let a = rendered[0].wrapped(below: .power)
            let b = rendered[1].wrapped(below: .power)
            return Rendered(text: "√(\(a)² + \(b)²)", precedence: .atom)
        case ("lerp", 3):
            let a = rendered[0].wrapped(below: .additive)
            let b = rendered[1].wrapped(below: .additive)
            let t = rendered[2].wrapped(below: .multiplicative)
            return Rendered(text: "\(a) + \(t)·(\(b) − \(rendered[0].wrapped(atOrBelow: .additive)))", precedence: .additive)
        case ("random", 0):
            return Rendered(text: "U(0, 1)", precedence: .atom)
        case ("random", 2):
            return Rendered(text: "U(\(args[0]), \(args[1]))", precedence: .atom)
        case ("emit", 3):
            return Rendered(text: "P ← (\(args[0]), \(args[1]), \(args[2]))", precedence: .atom)
        default:
            return Rendered(text: "\(name)(\(args.joined(separator: ", ")))", precedence: .atom)
        }
    }

    // MARK: - Helpers

    private static func isCall(_ expression: Expression) -> Bool {
        if case .call = expression { return true }
        return false
    }

    /// Terms that can follow a numeric coefficient without an explicit multiplication sign.
    private static func isJuxtaposable(_ expression: Expression) -> Bool {
        switch expression {
        case .identifier, .call:
            return true
        case .binary(let op, let lhs, _, _) where op == .caret:
            if case .identifier = lhs { return true }
            if case .call = lhs { return true }
            return false
        default:
            return false
        }
    }

    private static func startsWithLetterOrSymbol(_ text: String) -> Bool {
        guard let firstCharacter = text.first else { return false }
        return firstCharacter.isLetter || "πτ√⌊⌈|".contains(firstCharacter)
    }

    private static let superscriptDigits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
    private static let subscriptDigits: [Character] = ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
    private static let subscriptLetters: [Character: Character] = [
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ",
        "n": "ₙ", "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]
    private static let greekNames: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "zeta": "ζ", "eta": "η",
        "theta": "θ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
        "rho": "ρ", "sigma": "σ", "tau": "τ", "phi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Sigma": "Σ", "Phi": "Φ", "Omega": "Ω",
    ]

    /// Small non-negative or negative integers become superscripts: `x²`, `x⁻¹`.
    private static func superscriptInteger(_ value: Double) -> String? {
        guard value == value.rounded(), abs(value) < 100 else { return nil }
        let magnitude = Int(abs(value))
        var digits = String(magnitude).compactMap { $0.wholeNumberValue }.map { superscriptDigits[$0] }
        if value < 0 { digits.insert("⁻", at: 0) }
        return String(digits)
    }

    /// Prettifies an identifier: Greek names, trailing digits as subscripts (`x1` → `x₁`),
    /// and `name_sub` → `nameₛᵤᵦ` when the subscript letters exist in Unicode.
    static func symbol(_ name: String) -> String {
        var base = name
        var subscriptPart = ""

        if let underscore = name.firstIndex(of: "_"), underscore != name.startIndex {
            base = String(name[..<underscore])
            subscriptPart = String(name[name.index(after: underscore)...])
        } else {
            let trailingDigits = name.reversed().prefix { $0.isNumber }
            if !trailingDigits.isEmpty, trailingDigits.count < name.count {
                subscriptPart = String(trailingDigits.reversed())
                base = String(name.dropLast(trailingDigits.count))
            }
        }

        let prettyBase = greekNames[base] ?? base
        guard !subscriptPart.isEmpty else { return prettyBase }

        var subscriptText = ""
        for character in subscriptPart {
            if let digit = character.wholeNumberValue {
                subscriptText.append(subscriptDigits[digit])
            } else if let letter = subscriptLetters[character] {
                subscriptText.append(letter)
            } else {
                // Not representable as a Unicode subscript; fall back to plain notation.
                return prettyBase + "_" + subscriptPart
            }
        }
        return prettyBase + subscriptText
    }

    /// Integers print without a fractional part; other values use up to 6 significant digits.
    static func formatNumber(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        var text = String(format: "%.6g", value)
        if text.contains("e") {
            // 1e-06 → 1×10⁻⁶
            let parts = text.split(separator: "e")
            if parts.count == 2, let exponent = Int(parts[1]), let sup = superscriptInteger(Double(exponent)) {
                text = "\(parts[0])×10\(sup)"
            }
        }
        return text
    }
}
