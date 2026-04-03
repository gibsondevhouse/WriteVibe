//
//  ArticlesDashboardView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - ArticlesDashboardView

struct ArticlesDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \Article.updatedAt, order: .reverse) private var articles: [Article]

    @State private var selectedArticleID: PersistentIdentifier? = nil
    @State private var filterStatus: PublishStatus? = nil
    @State private var searchText: String = ""
    @State private var isCreatingSeries = false
    @State private var isShowingNewArticle = false

    private var selectedArticle: Article? {
        guard let id = selectedArticleID else { return nil }
        return modelContext.model(for: id) as? Article
    }

    private var filteredAndSearched: [Article] {
        var result = Array(articles)
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
                    selectedArticleID = nil
                    appState.setCurrentArticle(nil)
                }
            } else {
                dashboardContent
            }
        }
        .sheet(isPresented: $isCreatingSeries) {
            NewSeriesSheet(isPresented: $isCreatingSeries) { article in
                modelContext.insert(article)
                try? modelContext.save()
                selectedArticleID = article.persistentModelID
                appState.setCurrentArticle(article.id)
            }
        }
        .onChange(of: appState.shouldPresentNewArticleFormFromCommand) { _, shouldPresent in
            guard shouldPresent else { return }

            selectedArticleID = nil
            appState.setCurrentArticle(nil)
            isShowingNewArticle = true
            appState.consumeNewArticleFormPresentationTrigger()
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        articleListRegion
            .overlay {
                if isShowingNewArticle {
                    NewArticleCard(
                        title: Binding(
                            get: { appState.activeDraft?.title ?? "" },
                            set: { appState.updateDraftField(.title, value: $0) }
                        ),
                        subtitle: Binding(
                            get: { appState.activeDraft?.subtitle ?? "" },
                            set: { appState.updateDraftField(.subtitle, value: $0) }
                        ),
                        selectedTone: Binding(
                            get: {
                                guard let toneRaw = appState.activeDraft?.tone,
                                      let tone = ArticleTone(rawValue: toneRaw) else {
                                    return .conversational
                                }
                                return tone
                            },
                            set: { appState.updateDraftField(.tone, value: $0.rawValue) }
                        ),
                        selectedLength: Binding(
                            get: {
                                guard let raw = appState.activeDraft?.targetLength,
                                      let length = ArticleLength(rawValue: raw) else {
                                    return .medium
                                }
                                return length
                            },
                            set: { appState.updateDraftField(.targetLength, value: $0.rawValue) }
                        ),
                        isTitleSuggested: appState.hasDraftSuggestion(for: .title),
                        isSubtitleSuggested: appState.hasDraftSuggestion(for: .subtitle),
                        isToneSuggested: appState.hasDraftSuggestion(for: .tone),
                        isLengthSuggested: appState.hasDraftSuggestion(for: .targetLength),
                        onAcceptSuggestion: { appState.acceptDraftSuggestion(for: $0) },
                        onRejectSuggestion: { appState.rejectDraftSuggestion(for: $0) },
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
                onNewArticle: {
                    appState.ensureDraftSessionForNewArticleForm()
                    isShowingNewArticle = true
                }
            )
            if filteredAndSearched.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSearched) { article in
                            ArticleListItem(article: article) {
                                selectedArticleID = article.persistentModelID
                                appState.setCurrentArticle(article.id)
                            } onDelete: {
                                modelContext.delete(article)
                                try? modelContext.save()
                                if appState.currentArticleID == article.id {
                                    appState.setCurrentArticle(nil)
                                }
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
        let finalTitle = title.trimmed.isEmpty
            ? "Untitled Article"
            : title.trimmed
        let article = Article(
            title: finalTitle,
            subtitle: subtitle.trimmed,
            topic: "",
            tone: tone,
            targetLength: targetLength
        )
        let titleBlock = ArticleBlock(type: .heading(level: 1), content: finalTitle, position: 0)
        let bodyBlock  = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        article.drafts = [ArticleDraft(title: "Draft 1", content: finalTitle)]
        modelContext.insert(article)
        try? modelContext.save()
        appState.clearDraftSession()
        isShowingNewArticle = false
        selectedArticleID = article.persistentModelID
        appState.setCurrentArticle(article.id)
    }
}
