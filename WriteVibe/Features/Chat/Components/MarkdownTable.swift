//
//  MarkdownTable.swift
//  WriteVibe
//

import SwiftUI

struct MarkdownTable: View {
    let headers: [String]
    let rows: [[String]]

    private static let opts = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )

    var body: some View {
        let colCount = max(headers.count, rows.map(\.count).max() ?? 0)
        if colCount > 0 {
            VStack(alignment: .leading, spacing: 0) {
                headerRow(colCount: colCount)

                Rectangle().fill(Color.accentColor.opacity(0.25)).frame(height: 1)

                dataRows(colCount: colCount)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func headerRow(colCount: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<colCount, id: \.self) { c in
                let a = (try? AttributedString(
                    markdown: c < headers.count ? headers[c] : "",
                    options: Self.opts
                )) ?? AttributedString(headers[safe: c] ?? "")
                Text(a)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.accentColor.opacity(0.1))
    }

    @ViewBuilder
    private func dataRows(colCount: Int) -> some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
            HStack(spacing: 0) {
                ForEach(0..<colCount, id: \.self) { c in
                    let cell = c < row.count ? row[c] : ""
                    let a = (try? AttributedString(markdown: cell, options: Self.opts))
                        ?? AttributedString(cell)
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
}
