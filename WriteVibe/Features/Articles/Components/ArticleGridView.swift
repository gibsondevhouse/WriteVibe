//
//  ArticleGridView.swift
//  WriteVibe
//

import SwiftUI

struct ArticleGridView: View {
    let filteredSingles: [Article]
    let filteredSeriesGroups: [(name: String, articles: [Article])]
    let filterStatus: PublishStatus?
    @Binding var piecesExpanded: Bool
    @Binding var seriesExpanded: Bool
    var onNewArticle: () -> Void
    var onNewSeries: () -> Void
    var onSelect: (Article) -> Void
    var onDelete: (Article) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                piecesSection
                seriesSection
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Pieces Section

    @ViewBuilder
    private var piecesSection: some View {
        if !filteredSingles.isEmpty || filterStatus == nil {
            sectionHeader(
                title: "Pieces",
                count: filteredSingles.count,
                isExpanded: piecesExpanded
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    piecesExpanded.toggle()
                }
            }

            if piecesExpanded {
                LazyVGrid(columns: columns, spacing: 16) {
                    NewItemCard(title: "New Article", icon: "square.and.pencil") {
                        onNewArticle()
                    }
                    ForEach(filteredSingles) { article in
                        ArticleCard(article: article) {
                            onSelect(article)
                        } onDelete: {
                            onDelete(article)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Series Section

    @ViewBuilder
    private var seriesSection: some View {
        if !filteredSeriesGroups.isEmpty || filterStatus == nil {
            sectionHeader(
                title: "Series",
                count: filteredSeriesGroups.reduce(0) { $0 + $1.articles.count },
                isExpanded: seriesExpanded
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    seriesExpanded.toggle()
                }
            }

            if seriesExpanded {
                LazyVGrid(columns: columns, spacing: 16) {
                    NewItemCard(title: "New Series", icon: "rectangle.stack.badge.plus") {
                        onNewSeries()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, filteredSeriesGroups.isEmpty ? 24 : 8)

                ForEach(filteredSeriesGroups, id: \.name) { group in
                    seriesGroupHeader(group.name)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(group.articles) { article in
                            ArticleCard(article: article) {
                                onSelect(article)
                            } onDelete: {
                                onDelete(article)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(
        title: String,
        count: Int,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.quaternary))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func seriesGroupHeader(_ name: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
