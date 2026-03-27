//
//  DashboardHeroCard.swift
//  WriteVibe
//

import SwiftUI

struct DashboardHeroCard: View {
    let articles: [Article]
    var onNewArticle: () -> Void
    var onNewSeries: () -> Void

    private var piecesCount: Int {
        articles.filter { $0.seriesName == nil }.count
    }

    private var seriesCount: Int {
        Set(articles.compactMap { $0.seriesName }).count
    }

    private var seriesArticleCount: Int {
        articles.filter { $0.seriesName != nil }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            piecesCard
            seriesCard
        }
        .padding(WVSpace.xxl)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: - Pieces Card

    private var piecesCard: some View {
        let pieces = articles.filter { $0.seriesName == nil }
        let totalWords = pieces.reduce(0) { $0 + $1.wordCount }
        let wordLabel = totalWords > 999
            ? String(format: "%.1fk", Double(totalWords) / 1000)
            : "\(totalWords)"
        let inProgressCount = pieces.filter { $0.publishStatus == .inProgress }.count

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(height: 2)
                .clipShape(.rect(topLeadingRadius: WVRadius.cardLg, topTrailingRadius: WVRadius.cardLg))

            VStack(alignment: .leading, spacing: WVSpace.lg) {
                cardHeader(
                    icon: "doc.text.fill",
                    iconColor: Color.accentColor,
                    iconBg: Color.accentColor.opacity(0.1),
                    title: "Pieces",
                    subtitle: "Standalone articles",
                    count: piecesCount
                )

                HStack(spacing: WVSpace.sm) {
                    LibraryStatPill(value: wordLabel, label: "words", icon: "text.alignleft")
                    LibraryStatPill(
                        value: "\(inProgressCount)",
                        label: "in progress",
                        icon: "pencil.circle"
                    )
                }

                Button(action: onNewArticle) {
                    Label("New Article", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(WVSpace.lg)
        }
        .wvCardLg()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Series Card

    private var seriesCard: some View {
        let totalWords = articles.reduce(0) { $0 + $1.wordCount }
        let wordLabel = totalWords > 999
            ? String(format: "%.1fk", Double(totalWords) / 1000)
            : "\(totalWords)"

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 2)
                .clipShape(.rect(topLeadingRadius: WVRadius.cardLg, topTrailingRadius: WVRadius.cardLg))

            VStack(alignment: .leading, spacing: WVSpace.lg) {
                cardHeader(
                    icon: "rectangle.stack.fill",
                    iconColor: .secondary,
                    iconBg: Color.primary.opacity(0.07),
                    title: "Series",
                    subtitle: "Multi-part collections",
                    count: seriesCount
                )

                HStack(spacing: WVSpace.sm) {
                    LibraryStatPill(value: "\(seriesArticleCount)", label: "articles", icon: "doc.text")
                    LibraryStatPill(value: wordLabel, label: "total words", icon: "text.alignleft")
                }

                Button(action: onNewSeries) {
                    Label("New Series", systemImage: "rectangle.stack.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(WVSpace.lg)
        }
        .wvCardLg()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared Header

    @ViewBuilder
    private func cardHeader(
        icon: String,
        iconColor: Color,
        iconBg: Color,
        title: String,
        subtitle: String,
        count: Int
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.wvHeadline)
                Text(subtitle)
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("total")
                    .font(.wvNano)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}
