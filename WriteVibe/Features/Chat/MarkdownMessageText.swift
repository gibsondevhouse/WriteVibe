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
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownParser.parse(content: content, isStreaming: isStreaming).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    // MARK: Rendering

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .h1(let s):
            inlineText(s, 20, .bold)
                .padding(.top, 18).padding(.bottom, 8)
        case .h2(let s):
            inlineText(s, 17, .semibold)
                .padding(.top, 16).padding(.bottom, 7)
        case .h3(let s):
            inlineText(s, 15, .semibold)
                .padding(.top, 12).padding(.bottom, 6)
        case .h4(let s):
            inlineText(s, 14, .semibold)
                .padding(.top, 10).padding(.bottom, 5)
        case .rule:
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 10)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)
                        inlineText(item, 14, .regular)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.tint)
                            .frame(minWidth: 22, alignment: .trailing)
                        inlineText(item, 14, .regular)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        case .code(let lang, let src):
            codeCanvas(lang: lang, src: src)
        case .blockquote(let lines):
            blockquoteView(lines)
        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)
        case .body(let s):
            inlineText(s, 14, .regular)
                .padding(.vertical, 2)
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
            .padding(.vertical, 8)
        }
        .padding(.vertical, 6)
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
