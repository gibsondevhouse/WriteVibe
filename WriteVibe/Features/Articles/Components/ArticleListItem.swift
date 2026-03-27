//
//  ArticleListItem.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ArticleListItem

struct ArticleListItem: View {
    let article: Article
    var onOpen: () -> Void
    var onDelete: () -> Void

    @State private var isHovered = false

    private var readingTime: Int {
        max(1, article.wordCount / 200)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: WVSpace.sm) {
                titleLine
                if !article.subtitle.isEmpty {
                    Text(article.subtitle)
                        .font(.wvFootnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                metadataLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WVSpace.lg)
            .background(isHovered ? Color.primary.opacity(0.03) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(WVAnim.card, value: isHovered)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Article", systemImage: "trash")
            }
        }
    }

    private var titleLine: some View {
        Text(article.title)
            .font(.wvSubhead)
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private var metadataLine: some View {
        HStack(spacing: WVSpace.sm) {
            statusPill
            Text("·")
                .foregroundStyle(.tertiary)
            Text("Updated \(article.updatedAt, style: .relative)")
                .foregroundStyle(.tertiary)
            Text("·")
                .foregroundStyle(.tertiary)
            Text("\(article.wordCount.formatted()) words · ~\(readingTime) min read")
                .foregroundStyle(.tertiary)
        }
        .font(.wvMicro)
    }

    private var statusPill: some View {
        HStack(spacing: WVSpace.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(article.publishStatus.rawValue)
                .foregroundStyle(statusColor)
        }
        .font(.wvMicro)
        .padding(.horizontal, WVSpace.sm)
        .padding(.vertical, 2)
        .background(Capsule().fill(statusColor.opacity(0.10)))
    }

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}
