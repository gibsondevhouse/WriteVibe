//
//  ArticlesDashboardView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - ArticlesDashboardView

struct ArticlesDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.updatedAt, order: .reverse) private var articles: [Article]

    @State private var selectedArticle: Article? = nil
    @State private var filterStatus: PublishStatus? = nil
    @State private var searchText: String = ""
    @State private var isCreatingSeries = false
    @State private var isShowingNewArticle = false

    private var filteredAndSearched: [Article] {
        var result = articles.filter { $0.seriesName == nil }
        if let status = filterStatus {
            result = result.filter { $0.publishStatus == status }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.subtitle.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        Group {
            if let article = selectedArticle {
                ArticleWorkspaceView(article: article) {
                    selectedArticle = nil
                }
            } else {
                dashboardContent
            }
        }
        .sheet(isPresented: $isCreatingSeries) {
            NewSeriesSheet(isPresented: $isCreatingSeries) { article in
                modelContext.insert(article)
                selectedArticle = article
            }
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        articleListRegion
            .overlay {
                if isShowingNewArticle {
                    NewArticleCard(
                        onCreate: createArticle,
                        onCancel: { isShowingNewArticle = false }
                    )
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isShowingNewArticle)
    }

    // MARK: - Article List Region

    private var articleListRegion: some View {
        VStack(spacing: 0) {
            ArticleListHeader(
                filterStatus: $filterStatus,
                searchText: $searchText,
                onNewArticle: { isShowingNewArticle = true }
            )
            if filteredAndSearched.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSearched) { article in
                            ArticleListItem(article: article) {
                                selectedArticle = article
                            } onDelete: {
                                modelContext.delete(article)
                            }
                        }
                    }
                    .padding(.horizontal, WVSpace.xxl)
                    .padding(.bottom, WVSpace.xxl)
                }
            }
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        if articles.isEmpty {
            ContentUnavailableView(
                "No Articles Yet",
                systemImage: "doc.text",
                description: Text("Create your first article to get started.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Matches",
                systemImage: "magnifyingglass",
                description: Text("Try adjusting your search or filters.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Create

    private func createArticle(title: String, subtitle: String, tone: ArticleTone, targetLength: ArticleLength) {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled Article"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let article = Article(
            title: finalTitle,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            topic: "",
            tone: tone,
            targetLength: targetLength
        )
        let titleBlock = ArticleBlock(type: .heading(level: 1), content: finalTitle, position: 0)
        let bodyBlock  = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        article.drafts = [ArticleDraft(title: "Draft 1", content: finalTitle)]
        modelContext.insert(article)
        isShowingNewArticle = false
        selectedArticle = article
    }
}
