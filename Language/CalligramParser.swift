import Foundation

/// Recursive-descent parser for CalligramScript.
nonisolated struct CalligramParser {
    private let tokens: [Token]
    private var index = 0

    private init(tokens: [Token]) {
        self.tokens = tokens
    }

    static func parse(_ source: String) throws -> [Statement] {
        let tokens = try CalligramLexer.tokenize(source)
        var parser = CalligramParser(tokens: tokens)
        return try parser.parseProgram()
    }

    // MARK: - Program / blocks

    private mutating func parseProgram() throws -> [Statement] {
        var statements: [Statement] = []
        skipNewlines()
        while !check(.eof) {
            statements.append(try parseStatement())
            try expectStatementEnd()
            skipNewlines()
        }
        return statements
    }

    private mutating func parseBlock() throws -> [Statement] {
        try expectSymbol(.leftBrace, message: "'{'가 필요합니다.")
        var statements: [Statement] = []
        skipNewlines()
        while !checkSymbol(.rightBrace) {
            if check(.eof) {
                throw CalligramError(message: "블록이 닫히지 않았습니다. '}'가 필요합니다.", location: current.location)
            }
            statements.append(try parseStatement())
            try expectStatementEnd()
            skipNewlines()
        }
        try expectSymbol(.rightBrace, message: "'}'가 필요합니다.")
        return statements
    }

    // MARK: - Statements

    private mutating func parseStatement() throws -> Statement {
        let location = current.location
        switch current.kind {
        case .keyword(.let), .keyword(.var):
            return try parseDeclaration()
        case .keyword(.for):
            return try parseForLoop()
        case .keyword(.if):
            return try parseConditional()
        case .identifier(let name):
            if let next = peekKind(1), case .symbol(let symbol) = next, Self.assignmentSymbols.contains(symbol) {
                advance() // identifier
                advance() // operator
                let value = try parseExpression()
                return .assignment(name: name, operator: symbol, value: value, location)
            }
            let expression = try parseExpression()
            return .expression(expression, location)
        case .keyword(.else):
            throw CalligramError(message: "'else'는 'if' 블록 바로 뒤에만 올 수 있습니다.", location: location)
        default:
            let expression = try parseExpression()
            return .expression(expression, location)
        }
    }

    private static let assignmentSymbols: Set<Symbol> = [.assign, .plusAssign, .minusAssign, .starAssign, .slashAssign]

    private mutating func parseDeclaration() throws -> Statement {
        let location = current.location
        let isConstant: Bool
        if case .keyword(.let) = current.kind { isConstant = true } else { isConstant = false }
        advance()
        guard case .identifier(let name) = current.kind else {
            throw CalligramError(message: "변수 이름이 필요합니다.", location: current.location)
        }
        advance()
        try expectSymbol(.assign, message: "'='가 필요합니다. 선언에는 초기값이 필요합니다.")
        let value = try parseExpression()
        return .declaration(name: name, isConstant: isConstant, value: value, location)
    }

    private mutating func parseForLoop() throws -> Statement {
        let location = current.location
        advance() // for
        guard case .identifier(let variable) = current.kind else {
            throw CalligramError(message: "반복 변수 이름이 필요합니다. 예: for i in 0..<10", location: current.location)
        }
        advance()
        guard case .keyword(.in) = current.kind else {
            throw CalligramError(message: "'in'이 필요합니다. 예: for i in 0..<10", location: current.location)
        }
        advance()
        let start = try parseExpression()
        let isInclusive: Bool
        if matchSymbol(.halfOpenRange) {
            isInclusive = false
        } else if matchSymbol(.closedRange) {
            isInclusive = true
        } else {
            throw CalligramError(message: "범위 연산자 '..<' 또는 '...'가 필요합니다.", location: current.location)
        }
        let end = try parseExpression()
        let body = try parseBlock()
        return .forLoop(variable: variable, start: start, end: end, isInclusive: isInclusive, body: body, location)
    }

    private mutating func parseConditional() throws -> Statement {
        let location = current.location
        advance() // if
        let condition = try parseExpression()
        let thenBody = try parseBlock()
        var elseBody: [Statement]?
        if case .keyword(.else) = current.kind {
            advance()
            if case .keyword(.if) = current.kind {
                elseBody = [try parseConditional()]
            } else {
                elseBody = try parseBlock()
            }
        }
        return .conditional(condition: condition, thenBody: thenBody, elseBody: elseBody, location)
    }

    // MARK: - Expressions (lowest to highest precedence)

    private mutating func parseExpression() throws -> Expression {
        try parseOr()
    }

    private mutating func parseOr() throws -> Expression {
        var lhs = try parseAnd()
        while checkSymbol(.or) {
            let location = current.location
            advance()
            let rhs = try parseAnd()
            lhs = .binary(operator: .or, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseAnd() throws -> Expression {
        var lhs = try parseEquality()
        while checkSymbol(.and) {
            let location = current.location
            advance()
            let rhs = try parseEquality()
            lhs = .binary(operator: .and, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseEquality() throws -> Expression {
        var lhs = try parseComparison()
        while let symbol = currentSymbol, symbol == .equal || symbol == .notEqual {
            let location = current.location
            advance()
            let rhs = try parseComparison()
            lhs = .binary(operator: symbol, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseComparison() throws -> Expression {
        var lhs = try parseAdditive()
        while let symbol = currentSymbol,
              symbol == .less || symbol == .lessEqual || symbol == .greater || symbol == .greaterEqual {
            let location = current.location
            advance()
            let rhs = try parseAdditive()
            lhs = .binary(operator: symbol, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseAdditive() throws -> Expression {
        var lhs = try parseMultiplicative()
        while let symbol = currentSymbol, symbol == .plus || symbol == .minus {
            let location = current.location
            advance()
            let rhs = try parseMultiplicative()
            lhs = .binary(operator: symbol, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseMultiplicative() throws -> Expression {
        var lhs = try parseUnary()
        while let symbol = currentSymbol, symbol == .star || symbol == .slash || symbol == .percent {
            let location = current.location
            advance()
            let rhs = try parseUnary()
            lhs = .binary(operator: symbol, lhs: lhs, rhs: rhs, location)
        }
        return lhs
    }

    private mutating func parseUnary() throws -> Expression {
        if let symbol = currentSymbol, symbol == .minus || symbol == .not || symbol == .plus {
            let location = current.location
            advance()
            let operand = try parseUnary()
            if symbol == .plus { return operand }
            return .unary(operator: symbol, operand: operand, location)
        }
        return try parsePower()
    }

    /// Exponentiation is right associative: 2 ^ 3 ^ 2 == 2 ^ (3 ^ 2).
    private mutating func parsePower() throws -> Expression {
        let base = try parsePrimary()
        if checkSymbol(.caret) {
            let location = current.location
            advance()
            let exponent = try parseUnary()
            return .binary(operator: .caret, lhs: base, rhs: exponent, location)
        }
        return base
    }

    private mutating func parsePrimary() throws -> Expression {
        let token = current
        switch token.kind {
        case .number(let value):
            advance()
            return .number(value, token.location)
        case .string(let value):
            advance()
            return .string(value, token.location)
        case .keyword(.true):
            advance()
            return .boolean(true, token.location)
        case .keyword(.false):
            advance()
            return .boolean(false, token.location)
        case .identifier(let name):
            advance()
            if checkSymbol(.leftParen) {
                let arguments = try parseArguments()
                return .call(name: name, arguments: arguments, token.location)
            }
            return .identifier(name, token.location)
        case .symbol(.leftParen):
            advance()
            skipNewlines()
            let inner = try parseExpression()
            skipNewlines()
            try expectSymbol(.rightParen, message: "')'가 필요합니다.")
            return inner
        case .newline, .eof:
            throw CalligramError(message: "식이 끝나지 않았습니다. 값이 필요합니다.", location: token.location)
        default:
            throw CalligramError(message: "예상하지 못한 토큰 \(token.kind.displayName)", location: token.location)
        }
    }

    private mutating func parseArguments() throws -> [Expression] {
        try expectSymbol(.leftParen, message: "'('가 필요합니다.")
        var arguments: [Expression] = []
        skipNewlines()
        if matchSymbol(.rightParen) { return arguments }
        while true {
            skipNewlines()
            arguments.append(try parseExpression())
            skipNewlines()
            if matchSymbol(.comma) { continue }
            try expectSymbol(.rightParen, message: "인자 목록을 닫는 ')'가 필요합니다.")
            return arguments
        }
    }

    // MARK: - Token utilities

    private var current: Token {
        tokens[min(index, tokens.count - 1)]
    }

    private var currentSymbol: Symbol? {
        if case .symbol(let symbol) = current.kind { return symbol }
        return nil
    }

    private func peekKind(_ offset: Int) -> TokenKind? {
        let position = index + offset
        return position < tokens.count ? tokens[position].kind : nil
    }

    private mutating func advance() {
        if index < tokens.count - 1 { index += 1 }
    }

    private func check(_ kind: TokenKind) -> Bool {
        current.kind == kind
    }

    private func checkSymbol(_ symbol: Symbol) -> Bool {
        currentSymbol == symbol
    }

    private mutating func matchSymbol(_ symbol: Symbol) -> Bool {
        if checkSymbol(symbol) {
            advance()
            return true
        }
        return false
    }

    private mutating func expectSymbol(_ symbol: Symbol, message: String) throws {
        guard matchSymbol(symbol) else {
            throw CalligramError(message: "\(message) (발견: \(current.kind.displayName))", location: current.location)
        }
    }

    private mutating func skipNewlines() {
        while check(.newline) { advance() }
    }

    /// A statement must be followed by a newline, a semicolon, a closing brace, or the end of input.
    private mutating func expectStatementEnd() throws {
        if check(.newline) || check(.eof) || checkSymbol(.rightBrace) { return }
        if matchSymbol(.semicolon) { return }
        throw CalligramError(message: "문장이 끝나야 합니다. 줄바꿈 또는 ';'가 필요합니다. (발견: \(current.kind.displayName))",
                             location: current.location)
    }
}
