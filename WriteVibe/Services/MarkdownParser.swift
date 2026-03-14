//
//  MarkdownParser.swift
//  WriteVibe
//

import Foundation

// MARK: - MarkdownBlock

enum MarkdownBlock {
    case h1(String), h2(String), h3(String), h4(String)
    case bullets([String])
    case numbered([String])
    case code(lang: String, src: String)
    case rule
    case blockquote([String])
    case table(headers: [String], rows: [[String]])
    case body(String)
}

// MARK: - MarkdownParser

enum MarkdownParser {

    static func parse(content: String, isStreaming: Bool) -> [MarkdownBlock] {
        let allLines = content.components(separatedBy: "\n")

        // During streaming the last "line" may be a partial token run (no trailing \n yet).
        // Never classify it as a heading/rule so its type can't thrash mid-token.
        let committed: [String]
        let partial: String?
        if isStreaming && !content.hasSuffix("\n") {
            committed = Array(allLines.dropLast())
            partial   = allLines.last.flatMap { $0.isEmpty ? nil : $0 }
        } else {
            committed = allLines
            partial   = nil
        }

        var result:           [MarkdownBlock] = []
        var pendingBullets:   [String]        = []
        var pendingNumbered:  [String]        = []
        var pendingBody:      [String]        = []
        var pendingQuote:     [String]        = []
        var pendingTableRows: [[String]]      = []
        var inCode                            = false
        var codeLang:         String          = ""
        var codeLines:        [String]        = []

        func flushBullets()  { if !pendingBullets.isEmpty  { result.append(.bullets(pendingBullets));  pendingBullets  = [] } }
        func flushNumbered() { if !pendingNumbered.isEmpty { result.append(.numbered(pendingNumbered)); pendingNumbered = [] } }
        func flushBody()     { if !pendingBody.isEmpty     { result.append(.body(pendingBody.joined(separator: "\n"))); pendingBody = [] } }
        func flushQuote()    { if !pendingQuote.isEmpty    { result.append(.blockquote(pendingQuote)); pendingQuote = [] } }
        func flushTable() {
            guard pendingTableRows.count >= 2 else {
                for r in pendingTableRows { pendingBody.append(r.joined(separator: " | ")) }
                pendingTableRows = []; return
            }
            let headers = pendingTableRows[0]
            let rows = Array(pendingTableRows.dropFirst(2))
            result.append(.table(headers: headers, rows: rows))
            pendingTableRows = []
        }
        func flushAll() { flushBullets(); flushNumbered(); flushQuote(); flushTable(); flushBody() }

        func parseTableRow(_ line: String) -> [String] {
            var s = line.trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("|") { s = String(s.dropFirst()) }
            if s.hasSuffix("|") { s = String(s.dropLast()) }
            return s.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        for line in committed {
            if inCode {
                let isFenceClose = line.trimmingCharacters(in: .whitespaces) == "```"
                if isFenceClose {
                    inCode = false
                    result.append(.code(lang: codeLang, src: codeLines.joined(separator: "\n")))
                    codeLines = []; codeLang = ""
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if line.hasPrefix("```") {
                flushAll()
                codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                inCode = true
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isRule = trimmed.count >= 3
                && (trimmed.allSatisfy { $0 == "-" }
                    || trimmed.allSatisfy { $0 == "*" }
                    || trimmed.allSatisfy { $0 == "=" })
            if isRule { flushAll(); result.append(.rule); continue }

            if line.hasPrefix("> ") || line == ">" {
                flushBullets(); flushNumbered(); flushTable(); flushBody()
                pendingQuote.append(line.hasPrefix("> ") ? String(line.dropFirst(2)) : "")
                continue
            } else {
                flushQuote()
            }

            let isTableRow = trimmed.hasPrefix("|") || (trimmed.contains("|") && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*"))
            if isTableRow {
                flushBullets(); flushNumbered(); flushBody()
                pendingTableRows.append(parseTableRow(line))
                continue
            } else {
                flushTable()
            }

            if line.hasPrefix("#### ") {
                flushAll(); result.append(.h4(String(line.dropFirst(5))))
            } else if line.hasPrefix("### ") {
                flushAll(); result.append(.h3(String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                flushAll(); result.append(.h2(String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                flushAll(); result.append(.h1(String(line.dropFirst(2))))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushNumbered(); flushBody()
                pendingBullets.append(String(line.dropFirst(2)))
            } else if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                flushBullets(); flushBody()
                pendingNumbered.append(line.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression))
            } else if trimmed.isEmpty {
                flushAll()
            } else {
                flushBullets(); flushNumbered()
                pendingBody.append(line)
            }
        }

        flushAll()
        if inCode && !codeLines.isEmpty { result.append(.code(lang: codeLang, src: codeLines.joined(separator: "\n"))) }
        if let p = partial { result.append(.body(p)) }
        return result
    }
}
