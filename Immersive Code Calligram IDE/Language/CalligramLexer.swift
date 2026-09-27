import Foundation

/// A position in the user's source code (1-based).
nonisolated struct SourceLocation: Sendable, Hashable {
    var line: Int
    var column: Int

    static let unknown = SourceLocation(line: 0, column: 0)
}

/// An error produced while lexing, parsing, or interpreting CalligramScript.
nonisolated struct CalligramError: Error, Sendable {
    var message: String
    var location: SourceLocation
}

nonisolated enum Keyword: String, Sendable {
    case `let`, `var`, `for`, `in`, `if`, `else`, `true`, `false`
}

nonisolated enum Symbol: String, Sendable, CaseIterable {
    case plus = "+", minus = "-", star = "*", slash = "/", percent = "%", caret = "^"
    case assign = "=", plusAssign = "+=", minusAssign = "-=", starAssign = "*=", slashAssign = "/="
    case equal = "==", notEqual = "!=", less = "<", lessEqual = "<=", greater = ">", greaterEqual = ">="
    case and = "&&", or = "||", not = "!"
    case leftParen = "(", rightParen = ")", leftBrace = "{", rightBrace = "}", comma = ","
    case halfOpenRange = "..<", closedRange = "...", semicolon = ";"
}

nonisolated enum TokenKind: Sendable, Equatable {
    case number(Double)
    case string(String)
    case identifier(String)
    case keyword(Keyword)
    case symbol(Symbol)
    case newline
    case eof

    var displayName: String {
        switch self {
        case .number(let value): return "숫자 \(value)"
        case .string(let value): return "문자열 \"\(value)\""
        case .identifier(let name): return "식별자 '\(name)'"
        case .keyword(let keyword): return "키워드 '\(keyword.rawValue)'"
        case .symbol(let symbol): return "'\(symbol.rawValue)'"
        case .newline: return "줄바꿈"
        case .eof: return "파일 끝"
        }
    }
}

nonisolated struct Token: Sendable {
    var kind: TokenKind
    var location: SourceLocation
}

/// Converts CalligramScript source text into tokens.
nonisolated struct CalligramLexer {
    private let characters: [Character]
    private var index = 0
    private var line = 1
    private var column = 1

    private init(source: String) {
        characters = Array(source)
    }

    static func tokenize(_ source: String) throws -> [Token] {
        var lexer = CalligramLexer(source: source)
        return try lexer.tokenizeAll()
    }

    // MARK: - Driver

    private mutating func tokenizeAll() throws -> [Token] {
        var tokens: [Token] = []
        while true {
            let token = try nextToken()
            // Collapse consecutive newlines so the parser only sees one separator.
            if case .newline = token.kind, let last = tokens.last, case .newline = last.kind {
                continue
            }
            tokens.append(token)
            if case .eof = token.kind { break }
        }
        return tokens
    }

    private mutating func nextToken() throws -> Token {
        try skipWhitespaceAndComments()
        let location = SourceLocation(line: line, column: column)
        guard let character = peek() else {
            return Token(kind: .eof, location: location)
        }
        if character == "\n" {
            advance()
            return Token(kind: .newline, location: location)
        }
        if character.isNumber {
            return try lexNumber(at: location)
        }
        if character.isLetter || character == "_" {
            return lexIdentifier(at: location)
        }
        if character == "\"" {
            return try lexString(at: location)
        }
        return try lexSymbol(at: location)
    }

    // MARK: - Helpers

    private func peek(_ offset: Int = 0) -> Character? {
        let position = index + offset
        return position < characters.count ? characters[position] : nil
    }

    @discardableResult
    private mutating func advance() -> Character {
        let character = characters[index]
        index += 1
        if character == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return character
    }

    private mutating func skipWhitespaceAndComments() throws {
        while let character = peek() {
            if character == " " || character == "\t" || character == "\r" {
                advance()
            } else if character == "/" && peek(1) == "/" {
                while let next = peek(), next != "\n" { advance() }
            } else if character == "/" && peek(1) == "*" {
                let start = SourceLocation(line: line, column: column)
                advance(); advance()
                var closed = false
                while let next = peek() {
                    if next == "*" && peek(1) == "/" {
                        advance(); advance()
                        closed = true
                        break
                    }
                    advance()
                }
                if !closed {
                    throw CalligramError(message: "블록 주석이 닫히지 않았습니다.", location: start)
                }
            } else {
                break
            }
        }
    }

    private mutating func lexNumber(at location: SourceLocation) throws -> Token {
        var text = ""
        while let character = peek(), character.isNumber {
            text.append(advance())
        }
        // Only treat "." as a decimal point when a digit follows, so "0..<n" still lexes as a range.
        if peek() == ".", let next = peek(1), next.isNumber {
            text.append(advance())
            while let character = peek(), character.isNumber {
                text.append(advance())
            }
        }
        if peek() == "e" || peek() == "E" {
            var lookahead = 1
            if peek(lookahead) == "+" || peek(lookahead) == "-" { lookahead += 1 }
            if let digit = peek(lookahead), digit.isNumber {
                for _ in 0..<lookahead { text.append(advance()) }
                while let character = peek(), character.isNumber {
                    text.append(advance())
                }
            }
        }
        guard let value = Double(text) else {
            throw CalligramError(message: "숫자를 해석할 수 없습니다: \(text)", location: location)
        }
        return Token(kind: .number(value), location: location)
    }

    private mutating func lexIdentifier(at location: SourceLocation) -> Token {
        var text = ""
        while let character = peek(), character.isLetter || character.isNumber || character == "_" {
            text.append(advance())
        }
        if let keyword = Keyword(rawValue: text) {
            return Token(kind: .keyword(keyword), location: location)
        }
        return Token(kind: .identifier(text), location: location)
    }

    private mutating func lexString(at location: SourceLocation) throws -> Token {
        advance() // opening quote
        var text = ""
        while let character = peek() {
            if character == "\"" {
                advance()
                return Token(kind: .string(text), location: location)
            }
            if character == "\n" { break }
            if character == "\\" {
                advance()
                guard let escaped = peek() else { break }
                advance()
                switch escaped {
                case "n": text.append("\n")
                case "t": text.append("\t")
                case "\"": text.append("\"")
                case "\\": text.append("\\")
                default: text.append(escaped)
                }
                continue
            }
            text.append(advance())
        }
        throw CalligramError(message: "문자열이 닫히지 않았습니다.", location: location)
    }

    private mutating func lexSymbol(at location: SourceLocation) throws -> Token {
        for length in stride(from: 3, through: 1, by: -1) {
            var candidate = ""
            for offset in 0..<length {
                guard let character = peek(offset) else { break }
                candidate.append(character)
            }
            if candidate.count == length, let symbol = Symbol(rawValue: candidate) {
                for _ in 0..<length { advance() }
                return Token(kind: .symbol(symbol), location: location)
            }
        }
        let unexpected = peek().map(String.init) ?? ""
        throw CalligramError(message: "알 수 없는 문자 '\(unexpected)'", location: location)
    }
}
