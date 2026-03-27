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

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: WVSpace.lg) {
                leftContent
                Spacer(minLength: WVSpace.sm)
                rightContent
            }
            .padding(WVSpace.base)
            .background(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.10 : 0.05), lineWidth: 1)
            )
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

    // MARK: - Left Content

    private var leftContent: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text(article.title)
                .font(.wvSubhead)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !article.subtitle.isEmpty {
                Text(article.subtitle)
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Right Content

    private var rightContent: some View {
        VStack(alignment: .trailing, spacing: WVSpace.xs) {
            statusBadge
            metadataStack
        }
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Label(article.publishStatus.rawValue, systemImage: article.publishStatus.icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(statusColor)
            .padding(.horizontal, WVSpace.sm)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(statusColor.opacity(0.12))
            )
    }

    // MARK: - Metadata

    private var metadataStack: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(article.updatedAt, style: .relative)
                .font(.wvNano)
                .foregroundStyle(.quaternary)

            Text("\(article.wordCount.formatted()) words")
                .font(.wvNano)
                .foregroundStyle(.quaternary)
        }
    }

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}
