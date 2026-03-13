//
//  MarkdownMessageText.swift
//  WriteVibe
//

import SwiftUI

// MARK: - MarkdownMessageText

struct MarkdownMessageText: View {
    let content: String
    let isStreaming: Bool
    private static let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parsedBlocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: Block model

    private enum Block {
        case h1(String), h2(String), h3(String), h4(String)
        case bullets([String])
        case numbered([String])
        // lang is the optional fence info string (e.g. "swift", "bash")
        case code(lang: String, src: String)
        case rule
        case blockquote([String])
        // headers + rows (each row is an array of cell strings)
        case table(headers: [String], rows: [[String]])
        case body(String)
    }

    // MARK: Parser

    private var parsedBlocks: [Block] {
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

        var result:           [Block]    = []
        var pendingBullets:   [String]   = []
        var pendingNumbered:  [String]   = []
        var pendingBody:      [String]   = []
        var pendingQuote:     [String]   = []
        var pendingTableRows: [[String]] = [] // first entry is headers
        var inCode                       = false
        var codeLang:         String     = ""
        var codeLines:        [String]   = []

        func flushBullets()  { if !pendingBullets.isEmpty  { result.append(.bullets(pendingBullets));  pendingBullets  = [] } }
        func flushNumbered() { if !pendingNumbered.isEmpty { result.append(.numbered(pendingNumbered)); pendingNumbered = [] } }
        func flushBody()     { if !pendingBody.isEmpty     { result.append(.body(pendingBody.joined(separator: "\n"))); pendingBody = [] } }
        func flushQuote()    { if !pendingQuote.isEmpty    { result.append(.blockquote(pendingQuote)); pendingQuote = [] } }
        func flushTable() {
            guard pendingTableRows.count >= 2 else {
                // Not enough rows for a real table — drop it into body as-is
                for r in pendingTableRows { pendingBody.append(r.joined(separator: " | ")) }
                pendingTableRows = []; return
            }
            let headers = pendingTableRows[0]
            // Row index 1 is the separator (---|---) — skip it
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
                // A closing fence is exactly ``` with nothing (or only whitespace) after it.
                // Lines like ```python or ```swift inside a block are content, not closers.
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

            // Horizontal rule: ---, ***, ===  (3+ identical chars, optional spaces)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isRule = trimmed.count >= 3
                && (trimmed.allSatisfy { $0 == "-" }
                    || trimmed.allSatisfy { $0 == "*" }
                    || trimmed.allSatisfy { $0 == "=" })
            if isRule { flushAll(); result.append(.rule); continue }

            // Blockquote: lines starting with "> "
            if line.hasPrefix("> ") || line == ">" {
                flushBullets(); flushNumbered(); flushTable(); flushBody()
                pendingQuote.append(line.hasPrefix("> ") ? String(line.dropFirst(2)) : "")
                continue
            } else {
                flushQuote()
            }

            // Table: lines containing | (and not already a heading/list)
            let isTableRow = trimmed.hasPrefix("|") || (trimmed.contains("|") && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("*"))
            if isTableRow {
                flushBullets(); flushNumbered(); flushBody()
                // Separator row (e.g. |---|---|) — keep as a marker row so flushTable can skip it
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
        // Unclosed fence at stream end — render what we have
        if inCode && !codeLines.isEmpty { result.append(.code(lang: codeLang, src: codeLines.joined(separator: "\n"))) }
        if let p = partial { result.append(.body(p)) }
        return result
    }

    // MARK: Rendering

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .h1(let s):
            inlineText(s, 20, .bold)
                .padding(.top, 18).padding(.bottom, 4)
        case .h2(let s):
            inlineText(s, 17, .semibold)
                .padding(.top, 14).padding(.bottom, 3)
        case .h3(let s):
            inlineText(s, 15, .semibold)
                .padding(.top, 10).padding(.bottom, 2)
        case .h4(let s):
            inlineText(s, 14, .semibold)
                .padding(.top, 8).padding(.bottom, 1)
        case .rule:
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 10)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)
                        inlineText(item, 14, .regular)
                    }
                }
            }
            .padding(.top, 4)
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 9) {
                        Text("\(i + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(minWidth: 22, alignment: .trailing)
                        inlineText(item, 14, .regular)
                    }
                }
            }
            .padding(.top, 4)
        case .code(let lang, let src):
            codeCanvas(lang: lang, src: src)
        case .blockquote(let lines):
            blockquoteView(lines)
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
        case .body(let s):
            inlineText(s, 14, .regular)
                .padding(.top, 4)
        }
    }

    private func inlineText(_ s: String, _ sz: CGFloat, _ w: Font.Weight) -> some View {
        let a = (try? AttributedString(markdown: s, options: Self.opts)) ?? AttributedString(s)
        return Text(a)
            .font(.system(size: sz, weight: w))
            .lineSpacing(5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Markdown canvas — styled code block with optional language badge
    @ViewBuilder
    private func codeCanvas(lang: String, src: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !lang.isEmpty {
                HStack {
                    Text(lang.lowercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    // Copy button
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(src, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy code")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.07))

                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(height: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(src)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .background(Color(.textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
        }
        .padding(.vertical, 6)
    }

    // Blockquote — left accent bar, slightly indented, muted text
    @ViewBuilder
    private func blockquoteView(_ lines: [String]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)
                .cornerRadius(1.5)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let a = (try? AttributedString(markdown: line, options: Self.opts)) ?? AttributedString(line)
                    Text(a)
                        .font(.system(size: 14, weight: .regular))
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
        }
        .padding(.vertical, 4)
    }

    // Table — header row + striped data rows
    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        let colCount = max(headers.count, rows.map(\.count).max() ?? 0)
        if colCount > 0 {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { c in
                        let a = (try? AttributedString(markdown: c < headers.count ? headers[c] : "", options: Self.opts)) ?? AttributedString(headers[safe: c] ?? "")
                        Text(a)
                            .font(.system(size: 13, weight: .semibold))
                            .lineSpacing(4)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.accentColor.opacity(0.1))

                Rectangle().fill(Color.accentColor.opacity(0.25)).frame(height: 1)

                // Data rows
                ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                    HStack(spacing: 0) {
                        ForEach(0..<colCount, id: \.self) { c in
                            let cell = c < row.count ? row[c] : ""
                            let a = (try? AttributedString(markdown: cell, options: Self.opts)) ?? AttributedString(cell)
                            Text(a)
                                .font(.system(size: 13))
                                .lineSpacing(4)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .background(ri.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03))

                    if ri < rows.count - 1 {
                        Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .padding(.vertical, 6)
        }
    }
}
