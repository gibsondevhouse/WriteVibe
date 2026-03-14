//
//  BlockRowView.swift
//  WriteVibe
//
//  Renders a single ArticleBlock as an editable text field.
//  Change spans are rendered as inline highlighted runs using
//  AttributedString overlays so the base text is never mutated.
//

import SwiftUI

// MARK: - BlockRowView

struct BlockRowView: View {
    @Bindable var block: ArticleBlock
    let spans: [ChangeSpan]
    let showEdits: Bool
    let onAccept: (ChangeSpan) -> Void
    let onReject: (ChangeSpan) -> Void
    /// Called when the user presses Return at end-of-block to add a new paragraph
    let onReturnAtEnd: () -> Void
    /// Called when the block becomes empty and the user presses Backspace
    let onDeleteEmpty: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showEdits && !spans.isEmpty {
                diffAttributedView
                    .frame(maxWidth: .infinity, alignment: .leading)
                reviewActions
            } else {
                plainEditor
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Plain editor (no pending edits)

    @ViewBuilder
    private var plainEditor: some View {
        let isEditable = block.blockType.isTextEditable
        if isEditable {
            TextField(
                block.blockType.defaultPlaceholder,
                text: $block.content,
                axis: .vertical
            )
            .font(blockFont)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit { onReturnAtEnd() }
        } else {
            // Image block placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 140)
                .overlay(
                    Label("Image", systemImage: "photo")
                        .foregroundStyle(.secondary)
                )
        }
    }

    // MARK: - Diff attributed string view

    private var diffAttributedView: some View {
        Text(buildAttributedString())
            .font(blockFont)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineSpacing(3)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString(block.content)

        for span in spans {
            guard span.proposedRange.lowerBound < block.content.endIndex,
                  span.proposedRange.upperBound <= block.content.endIndex else { continue }

            let lower = AttributedString.Index(span.proposedRange.lowerBound, within: result)
            let upper = AttributedString.Index(span.proposedRange.upperBound, within: result)
            guard let lo = lower, let hi = upper else { continue }
            let attrRange = lo..<hi

            switch span.changeType {
            case .insert:
                result[attrRange].backgroundColor = .green.opacity(0.25)
                result[attrRange].underlineStyle  = .single

            case .delete:
                // delete spans have no range in current text; shown in review row below
                break

            case .replace:
                result[attrRange].backgroundColor = .orange.opacity(0.2)
                result[attrRange].underlineStyle  = .single
            }
        }
        return result
    }

    // MARK: - Per-span review row

    @ViewBuilder
    private var reviewActions: some View {
        VStack(spacing: 4) {
            ForEach(spans) { span in
                SpanReviewRow(span: span, blockContent: block.content) {
                    onAccept(span)
                } onReject: {
                    onReject(span)
                }
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Typography per block type

    private var blockFont: Font {
        switch block.blockType {
        case .heading(let level):
            switch level {
            case 1: return .system(size: 28, weight: .bold)
            case 2: return .system(size: 22, weight: .semibold)
            case 3: return .system(size: 18, weight: .semibold)
            default: return .system(size: 15, weight: .medium)
            }
        case .blockquote: return .system(size: 16).italic()
        case .code:       return .system(size: 13, design: .monospaced)
        default:          return .system(size: 15)
        }
    }
}

// MARK: - SpanReviewRow

private struct SpanReviewRow: View {
    let span: ChangeSpan
    let blockContent: String
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon + description
            Image(systemName: spanIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(spanColor)
                .frame(width: 14)

            Text(spanDescription)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Accept
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { onAccept() }
            } label: {
                Label("Accept", systemImage: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.green.opacity(0.12)))

            // Reject
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { onReject() }
            } label: {
                Label("Reject", systemImage: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.red.opacity(0.10)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.6))
        )
    }

    private var spanIcon: String {
        switch span.changeType {
        case .insert:  return "plus"
        case .delete:  return "minus"
        case .replace: return "arrow.left.arrow.right"
        }
    }

    private var spanColor: Color {
        switch span.changeType {
        case .insert:  return .green
        case .delete:  return .red
        case .replace: return .orange
        }
    }

    private var spanDescription: String {
        switch span.changeType {
        case .insert:
            return "Add \(span.proposedText ?? "")"
        case .delete:
            return "Remove \(span.originalText ?? "")"
        case .replace:
            return "\(span.originalText ?? "") → \(span.proposedText ?? "")"
        }
    }
}
