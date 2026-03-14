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
    @State private var isCreating = false
    @State private var newTitle = ""
    @State private var newSubtitle = ""
    @State private var newTopic = ""
    @State private var newTone: ArticleTone = .conversational
    @State private var newTargetLength: ArticleLength = .medium
    @State private var filterStatus: PublishStatus? = nil
    @State private var singleArticlesExpanded: Bool = true
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
                ArticleEditorView(article: article) {
                    selectedArticle = nil
                }
            } else {
                dashboardContent
            }
        }
        .sheet(isPresented: $isCreating) {
            newArticleSheet
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
                    // MARK: Single Articles section
                    if !filteredSingles.isEmpty || filterStatus == nil {
                        articleSectionHeader(
                            title: "Single Articles",
                            count: filteredSingles.count,
                            isExpanded: singleArticlesExpanded
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                singleArticlesExpanded.toggle()
                            }
                        }

                        if singleArticlesExpanded {
                            LazyVGrid(columns: columns, spacing: 16) {
                                NewItemCard(title: "New Article", icon: "square.and.pencil") {
                                    newTitle = ""
                                    newSubtitle = ""
                                    isCreating = true
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
        let totalWords = articles.reduce(0) { $0 + $1.wordCount }
        let inProgressCount = articles.filter { $0.publishStatus == .inProgress }.count
        let doneCount = articles.filter { $0.publishStatus == .done }.count
        let wordLabel = totalWords > 999
            ? String(format: "%.1fk", Double(totalWords) / 1000)
            : "\(totalWords)"

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                // Identity
                HStack(spacing: 12) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Articles")
                            .font(.system(size: 22, weight: .bold))
                        Text("Your personal writing library")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    Button {
                        newSeriesName = ""
                        newSeriesArticleTitle = ""
                        isCreatingSeries = true
                    } label: {
                        Label("New Series", systemImage: "rectangle.stack.badge.plus")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        newTitle = ""
                        newSubtitle = ""
                        isCreating = true
                    } label: {
                        Label("New Article", systemImage: "plus")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }

            // Stats row
            HStack(spacing: 10) {
                LibraryStatPill(value: "\(articles.count)", label: articles.count == 1 ? "piece" : "pieces", icon: "doc.text")
                LibraryStatPill(value: "\(seriesCount)", label: seriesCount == 1 ? "series" : "series", icon: "rectangle.stack")
                LibraryStatPill(value: "\(inProgressCount)", label: "in progress", icon: "pencil.circle")
                LibraryStatPill(value: "\(doneCount)", label: "published", icon: "checkmark.circle.fill")
                LibraryStatPill(value: wordLabel, label: "total words", icon: "text.alignleft")
            }
        }
        .padding(24)
        .background(Color.accentColor.opacity(0.06))
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

    // MARK: - New article sheet

    private var newArticleSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Text("New Article")
                        .font(.title3.weight(.semibold))
                }
                .padding(.bottom, 22)

                // Identity section
                sheetSectionLabel("Identity")

                fieldBlock("Title") {
                    TextField("Article title…", text: $newTitle)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock("Subtitle") {
                    TextField("Optional subtitle or deck…", text: $newSubtitle)
                        .textFieldStyle(.roundedBorder)
                }

                fieldBlock("Topic / Subject") {
                    TextField("What is this article about?", text: $newTopic)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.bottom, 20)

                // Style section
                sheetSectionLabel("Style")

                fieldBlock("Tone") {
                    Picker("Tone", selection: $newTone) {
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
                                isActive: newTargetLength == len
                            ) {
                                newTargetLength = len
                            }
                        }
                    }
                }
                .padding(.bottom, 28)

                // Actions
                HStack {
                    Button("Cancel") { isCreating = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Create") { createArticle() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(width: 480, height: 560)
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
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
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
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let article = Article(
            title: title,
            subtitle: newSubtitle.trimmingCharacters(in: .whitespaces),
            topic: newTopic.trimmingCharacters(in: .whitespaces),
            tone: newTone,
            targetLength: newTargetLength
        )
        let titleBlock = ArticleBlock(type: .heading(level: 1), content: title, position: 0)
        let bodyBlock  = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        modelContext.insert(article)
        isCreating = false
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
        modelContext.insert(article)
        isCreatingSeries = false
        selectedArticle = article
    }
}

// MARK: - ArticleCard

private struct ArticleCard: View {
    let article: Article
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                // Coloured header band
                Rectangle()
                    .fill(bandColor.gradient)
                    .frame(height: 6)
                    .clipShape(.rect(topLeadingRadius: 10, topTrailingRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(article.publishStatus.rawValue, systemImage: article.publishStatus.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(bandColor)
                        Spacer()
                        Text(article.updatedAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }

                    Text(article.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !article.subtitle.isEmpty {
                        Text(article.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        if let series = article.seriesName {
                            Label(series, systemImage: "rectangle.stack")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                        } else {
                            Spacer()
                        }
                        Text("\(article.wordCount) words")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(14)
                .frame(minHeight: 120, alignment: .topLeading)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(isHovered ? 0.14 : 0.07), radius: isHovered ? 10 : 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.07), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Article", systemImage: "trash")
            }
        }
    }

    private var bandColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}

// MARK: - NewItemCard

private struct NewItemCard: View {
    let title: String
    let icon: String
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3).gradient)
                    .frame(height: 6)
                    .clipShape(.rect(topLeadingRadius: 10, topTrailingRadius: 10))

                VStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(isHovered ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color.accentColor.opacity(isHovered ? 0.35 : 0.15),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - LengthChip

private struct LengthChip: View {
    let label: String
    let sub: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isActive ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LibraryStatPill

private struct LibraryStatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.background.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isActive ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.quaternary))
                )
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
