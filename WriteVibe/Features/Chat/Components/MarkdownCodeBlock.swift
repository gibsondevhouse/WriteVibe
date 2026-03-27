//
//  MarkdownCodeBlock.swift
//  WriteVibe
//

import SwiftUI

struct MarkdownCodeBlock: View {
    let lang: String
    let src: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !lang.isEmpty {
                HStack {
                    Text(lang.lowercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
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
}
