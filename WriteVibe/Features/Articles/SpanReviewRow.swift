//
//  SpanReviewRow.swift
//  WriteVibe
//

import SwiftUI

struct SpanReviewRow: View {
    let span: ChangeSpan
    let blockContent: String
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 10) {
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
