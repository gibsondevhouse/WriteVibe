//
//  ChatRewriteDiffCard.swift
//  WriteVibe
//

import SwiftUI

struct ChatRewriteDiffCard: View {
    let preview: ChatRewritePreview

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            header
            Text(highlightedRewrite())
                .font(.system(size: 13))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !preview.spans.isEmpty {
                VStack(alignment: .leading, spacing: WVSpace.xs) {
                    ForEach(preview.spans) { span in
                        changeRow(for: span)
                    }
                }
            }
        }
        .padding(WVSpace.base)
        .background(
            RoundedRectangle(cornerRadius: WVRadius.card, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WVRadius.card, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: WVSpace.sm) {
            Text(preview.action.title)
                .font(.wvMicro)
                .foregroundStyle(.primary)
                .padding(.horizontal, WVSpace.sm)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.14), in: Capsule())

            Text("Delta from original")
                .font(.wvFootnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private func highlightedRewrite() -> AttributedString {
        var result = AttributedString(preview.rewrittenText)

        for span in preview.spans {
            guard span.changeType != .delete,
                  span.proposedRange.lowerBound < preview.rewrittenText.endIndex,
                  span.proposedRange.upperBound <= preview.rewrittenText.endIndex,
                  let lower = AttributedString.Index(span.proposedRange.lowerBound, within: result),
                  let upper = AttributedString.Index(span.proposedRange.upperBound, within: result) else {
                continue
            }

            let attributedRange = lower..<upper
            switch span.changeType {
            case .insert:
                result[attributedRange].backgroundColor = .green.opacity(0.18)
                result[attributedRange].underlineStyle = .single
            case .replace:
                result[attributedRange].backgroundColor = .orange.opacity(0.18)
                result[attributedRange].underlineStyle = .single
            case .delete:
                break
            }
        }

        return result
    }

    @ViewBuilder
    private func changeRow(for span: ChangeSpan) -> some View {
        HStack(alignment: .top, spacing: WVSpace.xs) {
            Text(changeLabel(for: span))
                .font(.wvNano)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            changeDescription(for: span)
                .font(.wvFootnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func changeDescription(for span: ChangeSpan) -> some View {
        switch span.changeType {
        case .insert:
            Text(verbatim: span.proposedText ?? "")
                .foregroundStyle(.green)
        case .delete:
            Text(verbatim: span.originalText ?? "")
                .strikethrough()
                .foregroundStyle(.red)
        case .replace:
            Text(
                "\(Text(verbatim: span.originalText ?? "").strikethrough().foregroundStyle(.red))\(Text(" -> ").foregroundStyle(.tertiary))\(Text(verbatim: span.proposedText ?? "").foregroundStyle(.green))"
            )
        }
    }

    private func changeLabel(for span: ChangeSpan) -> String {
        switch span.changeType {
        case .insert: return "Added"
        case .delete: return "Removed"
        case .replace: return "Changed"
        }
    }
}