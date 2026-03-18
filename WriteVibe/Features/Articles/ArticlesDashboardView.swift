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
    @State private var piecesExpanded: Bool = true
    @State private var seriesExpanded: Bool = true
    @State private var isCreatingSeries = false
    @State private var newSeriesName = ""
    @State private var newSeriesDescription = ""
    @State private var newSeriesArticleTitle = ""
    @State private var newSeriesTopic = ""
    @State private var newSeriesTone: ArticleTone = .conversational
    @State private var newSeriesLength: ArticleLength = .medium

    private var filtered: [Article] {
        guard let f = filterStatus else { return articles }
        return articles.filter { $0.publishStatus == f }
    }

    private var filteredSingles: [Article] {
        filtered.filter { $0.seriesName == nil }
    }

    private var filteredSeriesGroups: [(name: String, articles: [Article])] {
        let withSeries = filtered.filter { $0.seriesName != nil }
        var grouped: [String: [Article]] = [:]
        for article in withSeries {
            let key = article.seriesName!
            grouped[key, default: []].append(article)
        }
        return grouped
            .map { (name: $0.key, articles: $0.value.sorted { $0.updatedAt > $1.updatedAt }) }
            .sorted { $0.name < $1.name }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 16)
    ]

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
            newSeriesSheet
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            heroCard
            Divider()
            if !articles.isEmpty {
                filterBar
                Divider()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // MARK: Pieces section
                    if !filteredSingles.isEmpty || filterStatus == nil {
                        articleSectionHeader(
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
                                    createArticle()
                                }
                                ForEach(filteredSingles) { article in
                                    ArticleCard(article: article) {
                                        selectedArticle = article
                                    } onDelete: {
                                        modelContext.delete(article)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }

                    // MARK: Series section
                    if !filteredSeriesGroups.isEmpty || filterStatus == nil {
                        articleSectionHeader(
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
                                    newSeriesName = ""
                                    newSeriesArticleTitle = ""
                                    isCreatingSeries = true
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, filteredSeriesGroups.isEmpty ? 24 : 8)

                            ForEach(filteredSeriesGroups, id: \.name) { group in
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.stack")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Text(group.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                                .padding(.bottom, 8)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(group.articles) { article in
                                        ArticleCard(article: article) {
                                            selectedArticle = article
                                        } onDelete: {
                                            modelContext.delete(article)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var heroCard: some View {
        let seriesCount = Set(articles.compactMap { $0.seriesName }).count
        let piecesCount = articles.filter { $0.seriesName == nil }.count
        let seriesArticleCount = articles.filter { $0.seriesName != nil }.count
        let totalWords = articles.reduce(0) { $0 + $1.wordCount }
        let wordLabel = totalWords > 999
            ? String(format: "%.1fk", Double(totalWords) / 1000)
            : "\(totalWords)"

        let wp = articles.filter { $0.seriesName == nil }.reduce(0) { $0 + $1.wordCount }
        let wLabel = wp > 999 ? String(format: "%.1fk", Double(wp) / 1000) : "\(wp)"

        return HStack(alignment: .top, spacing: 16) {
            // MARK: Pieces card
            VStack(alignment: .leading, spacing: 0) {
                // Subtle 2pt accent rule
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(height: 2)
                    .clipShape(.rect(topLeadingRadius: WVRadius.cardLg, topTrailingRadius: WVRadius.cardLg))

                VStack(alignment: .leading, spacing: WVSpace.lg) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pieces")
                                .font(.wvHeadline)
                            Text("Standalone articles")
                                .font(.wvFootnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(piecesCount)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("total")
                                .font(.wvNano)
                                .foregroundStyle(.quaternary)
                        }
                    }

                    HStack(spacing: WVSpace.sm) {
                        LibraryStatPill(value: wLabel, label: "words", icon: "text.alignleft")
                        LibraryStatPill(
                            value: "\(articles.filter { $0.seriesName == nil && $0.publishStatus == .inProgress }.count)",
                            label: "in progress",
                            icon: "pencil.circle"
                        )
                    }

                    Button { createArticle() } label: {
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

            // MARK: Series card
            VStack(alignment: .leading, spacing: 0) {
                // Subtle 2pt neutral rule
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 2)
                    .clipShape(.rect(topLeadingRadius: WVRadius.cardLg, topTrailingRadius: WVRadius.cardLg))

                VStack(alignment: .leading, spacing: WVSpace.lg) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.07))
                                .frame(width: 36, height: 36)
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Series")
                                .font(.wvHeadline)
                            Text("Multi-part collections")
                                .font(.wvFootnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(seriesCount)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("total")
                                .font(.wvNano)
                                .foregroundStyle(.quaternary)
                        }
                    }

                    HStack(spacing: WVSpace.sm) {
                        LibraryStatPill(value: "\(seriesArticleCount)", label: "articles", icon: "doc.text")
                        LibraryStatPill(value: wordLabel, label: "total words", icon: "text.alignleft")
                    }

                    Button {
                        newSeriesName = ""
                        newSeriesArticleTitle = ""
                        isCreatingSeries = true
                    } label: {
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
        .padding(WVSpace.xxl)
        .background(Color(.windowBackgroundColor))
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            FilterChip(label: "All", isActive: filterStatus == nil) {
                filterStatus = nil
            }
            ForEach(PublishStatus.allCases, id: \.self) { status in
                FilterChip(label: status.rawValue, isActive: filterStatus == status) {
                    filterStatus = filterStatus == status ? nil : status
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    // MARK: - Section header

    private func articleSectionHeader(
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

    // MARK: - New series sheet

    private var newSeriesSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Text("New Series")
                        .font(.title3.weight(.semibold))
                }
                .padding(.bottom, 22)

                // Series identity
                sheetSectionLabel("Series")

                fieldBlock("Series Name") {
                    TextField("e.g. Swift Deep Dives", text: $newSeriesName)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock("Description") {
                    TextField("What is this series about? (optional)", text: $newSeriesDescription)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.bottom, 20)

                // First article
                sheetSectionLabel("First Article")

                fieldBlock("Title") {
                    TextField("Article title…", text: $newSeriesArticleTitle)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock("Topic / Subject") {
                    TextField("What does this article cover?", text: $newSeriesTopic)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock("Tone") {
                    Picker("Tone", selection: $newSeriesTone) {
                        ForEach(ArticleTone.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                fieldBlock("Target Length") {
                    HStack(spacing: 8) {
                        ForEach(ArticleLength.allCases, id: \.self) { len in
                            LengthChip(
                                label: len.rawValue,
                                sub: len.wordTarget,
                                isActive: newSeriesLength == len
                            ) {
                                newSeriesLength = len
                            }
                        }
                    }
                }
                .padding(.bottom, 28)

                // Actions
                HStack {
                    Button("Cancel") { isCreatingSeries = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create Series") { createSeriesFirstArticle() }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            newSeriesName.trimmingCharacters(in: .whitespaces).isEmpty ||
                            newSeriesArticleTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        )
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(width: 480, height: 640)
    }

    // MARK: - Sheet helpers

    @ViewBuilder
    private func sheetSectionLabel(_ text: String) -> some View {
        Text(text)
            .wvSectionLabel()
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.callout.weight(.medium))
            content()
        }
        .padding(.bottom, 14)
    }

    // MARK: - Create

    private func createArticle() {
        let untitledCount = articles.filter { $0.title.hasPrefix("Untitled Article") }.count + 1
        let title = untitledCount == 1 ? "Untitled Article" : "Untitled Article \(untitledCount)"
        let article = Article(
            title: title,
            subtitle: "",
            topic: "",
            tone: .conversational,
            targetLength: .medium
        )
        let titleBlock = ArticleBlock(type: .heading(level: 1), content: title, position: 0)
        let bodyBlock  = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        article.drafts = [ArticleDraft(title: "Draft 1", content: title)]
        modelContext.insert(article)
        selectedArticle = article
    }

    private func createSeriesFirstArticle() {
        let series = newSeriesName.trimmingCharacters(in: .whitespaces)
        let title = newSeriesArticleTitle.trimmingCharacters(in: .whitespaces)
        guard !series.isEmpty, !title.isEmpty else { return }
        let article = Article(
            title: title,
            subtitle: "",
            topic: newSeriesTopic.trimmingCharacters(in: .whitespaces),
            tone: newSeriesTone,
            targetLength: newSeriesLength
        )
        article.seriesName = series
        let titleBlock = ArticleBlock(type: .heading(level: 1), content: title, position: 0)
        let bodyBlock  = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        article.drafts = [ArticleDraft(title: "Draft 1", content: title)]
        modelContext.insert(article)
        isCreatingSeries = false
        selectedArticle = article
    }
}
