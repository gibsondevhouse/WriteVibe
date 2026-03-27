//
//  MarkdownBlockquote.swift
//  WriteVibe
//

import SwiftUI

struct MarkdownBlockquote: View {
    let lines: [String]

    private static let opts = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 3)
                .cornerRadius(1.5)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let a = (try? AttributedString(markdown: line, options: Self.opts))
                        ?? AttributedString(line)
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
}
