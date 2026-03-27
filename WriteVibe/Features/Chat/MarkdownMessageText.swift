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
            MarkdownCodeBlock(lang: lang, src: src)
        case .blockquote(let lines):
            MarkdownBlockquote(lines: lines)
        case .table(let headers, let rows):
            MarkdownTable(headers: headers, rows: rows)
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


}
