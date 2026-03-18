//
//  ArticleWorkspaceView.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ArticleWorkspaceView

struct ArticleWorkspaceView: View {
    @Bindable var article: Article
    let onBack: () -> Void

    @State private var isEditingArticle: Bool = false
    @State private var uploadStatusMessage: String? = nil
    @State private var isGeneratingOutline: Bool = false
    @State private var isGeneratingWordCount: Bool = false
    @State private var wordCountPlan: WordCountPlan? = nil
    @State private var outlineVM = ArticleEditorViewModel()

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 520), spacing: 18)
    ]

    private var sortedDrafts: [ArticleDraft] {
        article.drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var targetWordCeiling: Int {
        switch article.targetLength {
        case .brief:
            return 300
        case .short:
            return 500
        case .medium:
            return 1_000
        case .long:
            return 2_000
        case .deepDive:
            return 5_000
        }
    }

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:
            return .secondary
        case .inProgress:
            return .orange
        case .done:
            return .green
        }
    }

    var body: some View {
        Group {
            if isEditingArticle {
                ArticleEditorView(article: article) {
                    isEditingArticle = false
                }
            } else {
                workspaceContent
            }
        }

    }

    // MARK: - Layout

    private var workspaceContent: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            HStack(alignment: .top, spacing: 0) {
                articleDNAPanel
                Divider()

                ScrollView {
                    foundationCanvas
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: WVSpace.md) {
            Button(action: onBack) {
                HStack(spacing: WVSpace.xs) {
                    Image(systemName: "chevron.left")
                        .font(.wvLabel)
                    Text("Articles")
                        .font(.wvActionLabel)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            HStack(spacing: WVSpace.xs) {
                Image(systemName: article.publishStatus.icon)
                    .font(.wvLabel)
                    .foregroundStyle(statusColor)
                Text(article.publishStatus.rawValue)
                    .font(.wvLabel)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, WVSpace.sm)
            .padding(.vertical, WVSpace.xs)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Spacer()

            Text(article.updatedAt, style: .relative)
                .font(.wvFootnote)
                .foregroundStyle(.quaternary)

            Button {
                importDocument()
            } label: {
                Label("Import", systemImage: "doc.badge.plus")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                saveDraftSnapshot()
            } label: {
                Label("Snapshot", systemImage: "camera")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                isEditingArticle = true
            } label: {
                Label("Open Editor", systemImage: "square.and.pencil")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, WVSpace.xl)
        .padding(.vertical, WVSpace.sm)
    }

    private var articleDNAPanel: some View {
        VStack(alignment: .leading, spacing: WVSpace.lg) {
            Text("Article DNA")
                .wvSectionLabel()

            VStack(alignment: .leading, spacing: WVSpace.xs) {
                TextField("Title", text: $article.title)
                    .textFieldStyle(.plain)
                    .font(.wvHeroTitle)
                    .onChange(of: article.title) { _, _ in
                        article.updatedAt = Date()
                    }

                TextField("Subtitle", text: $article.subtitle)
                    .textFieldStyle(.plain)
                    .font(.wvBody)
                    .foregroundStyle(.secondary)
                    .onChange(of: article.subtitle) { _, _ in
                        article.updatedAt = Date()
                    }
            }

            Text("Set the voice, scope, and publishing intent before you draft.")
                .font(.wvFootnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text("Tone")
                    .font(.wvActionLabel)
                    .foregroundStyle(.secondary)
                Picker("Tone", selection: $article.tone) {
                    ForEach(ArticleTone.allCases, id: \.self) { tone in
                        Label(tone.rawValue, systemImage: tone.icon)
                            .tag(tone)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: article.tone) { _, _ in
                    article.updatedAt = Date()
                }
            }

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                Text("Target Length")
                    .font(.wvActionLabel)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 98, maximum: 110), spacing: WVSpace.xs)], spacing: WVSpace.xs) {
                    ForEach(ArticleLength.allCases, id: \.self) { len in
                        WorkspaceLengthChip(
                            label: len.rawValue,
                            sub: len.wordTarget,
                            isActive: article.targetLength == len
                        ) {
                            article.targetLength = len
                            article.updatedAt = Date()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text("Publish Status")
                    .font(.wvActionLabel)
                    .foregroundStyle(.secondary)

                Picker("Status", selection: $article.publishStatus) {
                    ForEach(PublishStatus.allCases, id: \.self) { status in
                        Label(status.rawValue, systemImage: status.icon)
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(statusColor)
                .foregroundStyle(statusColor)
                .onChange(of: article.publishStatus) { _, _ in
                    article.updatedAt = Date()
                }
            }

            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text("Word Progress")
                    .font(.wvActionLabel)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(article.wordCount), total: Double(targetWordCeiling))
                    .tint(.accentColor)

                Text("\(article.wordCount) / \(targetWordCeiling) words")
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Word Count Plan — Apple Intelligence estimate per section
            if #available(macOS 26, *), AppleIntelligenceService.isAvailable {
                VStack(alignment: .leading, spacing: WVSpace.xs) {
                    HStack {
                        Text("Word Count Plan")
                            .font(.wvActionLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            generateWordCountPlan()
                        } label: {
                            if isGeneratingWordCount {
                                ProgressView().controlSize(.mini).scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.wvNano)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingWordCount)
                        .help("Estimate words per section using Apple Intelligence")
                    }

                    if let plan = wordCountPlan {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(plan.sections, id: \.heading) { section in
                                HStack {
                                    Text(section.heading)
                                        .font(.wvNano)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("~\(section.estimatedWords)")
                                        .font(.wvNano)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            Divider()
                            HStack {
                                Text("Total estimate")
                                    .font(.wvLabel)
                                Spacer()
                                Text("~\(plan.totalEstimate)")
                                    .font(.wvLabel)
                                    .monospacedDigit()
                            }
                        }
                        .padding(WVSpace.sm)
                        .background(
                            RoundedRectangle(cornerRadius: WVRadius.card)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    } else if !isGeneratingWordCount {
                        Text("Tap ✦ to estimate.")
                            .font(.wvNano)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if let uploadStatusMessage {
                Text(uploadStatusMessage)
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, WVSpace.xs)
            }

            // Generate Outline button — Apple Intelligence only
            if #available(macOS 26, *), AppleIntelligenceService.isAvailable {
                Button {
                    generateOutline()
                } label: {
                    if isGeneratingOutline {
                        Label("Generating…", systemImage: "sparkles")
                            .font(.wvActionLabel)
                    } else {
                        Label("Generate Outline", systemImage: "list.bullet.rectangle")
                            .font(.wvActionLabel)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isGeneratingOutline || article.title.isEmpty)
                .help("Use Apple Intelligence to generate a structured outline from your article metadata")
            }

            Spacer(minLength: 0)

            Button {
                importDocument()
            } label: {
                Label("Upload Document", systemImage: "doc.badge.plus")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(WVSpace.lg)
        .frame(width: 252, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.background.opacity(0.6))
    }

    private var foundationCanvas: some View {
        VStack(alignment: .leading, spacing: WVSpace.xxl) {
            studioHero

            LazyVGrid(columns: columns, spacing: WVSpace.lg) {
                textCard(
                    title: "Premise",
                    subtitle: "Your argument in one or two sentences. What must the reader leave believing?",
                    text: $article.summary,
                    placeholder: "What is the one thing this piece must make the reader believe or understand?"
                )

                textCard(
                    title: "Audience",
                    subtitle: "Who are you writing for, and what do they already know?",
                    text: $article.audience,
                    placeholder: "e.g. General readers curious about American history. No prior knowledge assumed."
                )

                textCard(
                    title: "Outline",
                    subtitle: "The skeleton. Sections, scenes, arguments - rough order only.",
                    text: $article.outline,
                    placeholder: "Hook:\n\nMain argument:\n\nKey supporting points:\n  -\n  -\n  -\n\nCounterpoint or complication:\n\nConclusion:"
                )

                textCard(
                    title: "Research & Sources",
                    subtitle: "Quotes, links, facts, and raw material to draw from.",
                    text: $article.quickNotes,
                    placeholder: "Drop in quotes, citations, URLs, interview notes, and key facts - anything you'll want to reference while writing."
                )
            }

            draftsStrip
        }
        .padding(WVSpace.xxl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var studioHero: some View {
        HStack(alignment: .top, spacing: 0) {
            // Accent rule along the left edge
            Rectangle()
                .fill(Color.accentColor.opacity(0.45))
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: WVRadius.panel, bottomLeadingRadius: WVRadius.panel))

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                HStack(alignment: .firstTextBaseline, spacing: WVSpace.sm) {
                    Text("Writing Studio")
                        .font(.wvHeroTitle)
                    Spacer()
                    HStack(spacing: WVSpace.xs) {
                        WorkspacePill(icon: "lightbulb", text: "Premise")
                        WorkspacePill(icon: "person.2", text: "Audience")
                        WorkspacePill(icon: "list.bullet.rectangle", text: "Outline")
                        WorkspacePill(icon: "books.vertical", text: "Sources")
                    }
                }
                Text("Build your piece from premise to sources, then capture snapshots as you refine each draft.")
                    .font(.wvBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(WVSpace.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wvPanelCard()
    }

    private var draftsStrip: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            HStack(spacing: WVSpace.sm) {
                Text("Draft History")
                    .font(.wvActionLabel)
                WorkspacePill(icon: "doc.plaintext", text: "\(article.drafts.count) drafts")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WVSpace.sm) {
                    if sortedDrafts.isEmpty {
                        Text("No snapshots yet. Save one from the toolbar.")
                            .font(.wvBody)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(sortedDrafts) { draft in
                            VStack(alignment: .leading, spacing: WVSpace.xs) {
                                Text(draft.title)
                                    .font(.wvSubhead)
                                Text("\(draft.wordCount) words")
                                    .font(.wvFootnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, WVSpace.md)
                            .padding(.vertical, WVSpace.sm)
                            .wvCard()
                        }
                    }
                }
                .padding(.vertical, WVSpace.xs)
            }
        }
    }



    // MARK: - Cards

    private func textCard(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        WorkspaceCard(title: title, subtitle: subtitle) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.wvBody)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.wvBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 156)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -6)
                    .onChange(of: text.wrappedValue) { _, _ in
                        article.updatedAt = Date()
                    }
            }
        }
        .frame(height: 260)
    }

    // MARK: - Apple Intelligence Actions

    private func generateOutline() {
        guard #available(macOS 26, *), AppleIntelligenceService.isAvailable else { return }
        isGeneratingOutline = true
        uploadStatusMessage = nil
        Task { @MainActor in
            do {
                let outline = try await AppleIntelligenceService.generateOutline(
                    title: article.title,
                    topic: article.topic.isEmpty ? article.title : article.topic,
                    audience: article.audience.isEmpty ? "General" : article.audience,
                    targetLength: article.targetLength.rawValue
                )
                outlineVM.insertOutlineBlocks(outline, into: article)
                uploadStatusMessage = "Outline inserted into the editor (\(outline.sections.count) sections)."
            } catch {
                uploadStatusMessage = "Could not generate outline: \(error.localizedDescription)"
            }
            isGeneratingOutline = false
        }
    }

    private func generateWordCountPlan() {
        guard #available(macOS 26, *), AppleIntelligenceService.isAvailable else { return }
        isGeneratingWordCount = true
        Task { @MainActor in
            do {
                wordCountPlan = try await AppleIntelligenceService.generateWordCountPlan(
                    title: article.title,
                    outline: article.outline.isEmpty ? "No outline provided." : article.outline,
                    targetLength: article.targetLength.rawValue
                )
            } catch {
                // Silently discard — non-critical UI enhancement
            }
            isGeneratingWordCount = false
        }
    }

    // MARK: - Existing actions

    private func importDocument() {
        Task { @MainActor in
            do {
                guard let text = try await DocumentIngestionService.pickAndExtract() else {
                    uploadStatusMessage = "No document imported."
                    return
                }

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    uploadStatusMessage = "The selected document was empty."
                    return
                }

                let prefix = article.quickNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? ""
                    : "\n\n---\n\n"
                article.quickNotes += prefix + trimmed
                article.updatedAt = Date()
                uploadStatusMessage = "Document added to Quick Notes."
            } catch {
                uploadStatusMessage = error.localizedDescription
            }
        }
    }

    private func saveDraftSnapshot() {
        let content = article.blocks
            .sorted { $0.position < $1.position }
            .map { $0.content }
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !content.isEmpty else {
            uploadStatusMessage = "Write something in the editor first, then save a draft snapshot."
            return
        }

        let draftNumber = article.drafts.count + 1
        let snapshot = ArticleDraft(
            title: "Draft \(draftNumber)",
            content: content
        )
        article.drafts.append(snapshot)
        article.updatedAt = Date()
        uploadStatusMessage = "Saved Draft \(draftNumber)."
    }
}
