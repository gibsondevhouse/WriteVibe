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
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Articles")
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            HStack(spacing: 5) {
                Image(systemName: article.publishStatus.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusColor)
                Text(article.publishStatus.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Spacer()

            Text(article.updatedAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)

            Button {
                importDocument()
            } label: {
                Label("Import", systemImage: "doc.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                saveDraftSnapshot()
            } label: {
                Label("Snapshot", systemImage: "camera")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                isEditingArticle = true
            } label: {
                Label("Open Editor", systemImage: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var articleDNAPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ARTICLE DNA")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.9)

            TextField("Title", text: $article.title)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .bold))
                .onChange(of: article.title) { _, _ in
                    article.updatedAt = Date()
                }

            TextField("Subtitle", text: $article.subtitle)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(.secondary)
                .onChange(of: article.subtitle) { _, _ in
                    article.updatedAt = Date()
                }

            Text("Set the voice, scope, and publishing intent before you draft.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Tone")
                    .font(.system(size: 11, weight: .semibold))
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Target Length")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 98, maximum: 110), spacing: 6)], spacing: 6) {
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Publish Status")
                    .font(.system(size: 11, weight: .semibold))
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

            VStack(alignment: .leading, spacing: 6) {
                Text("Word Progress")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(article.wordCount), total: Double(targetWordCeiling))
                    .tint(.accentColor)

                Text("\(article.wordCount) / \(targetWordCeiling) words")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let uploadStatusMessage {
                Text(uploadStatusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            }

            Spacer(minLength: 0)

            Button {
                importDocument()
            } label: {
                Label("Upload Document", systemImage: "doc.badge.plus")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(18)
        .frame(width: 248, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color.secondary.opacity(0.09),
                    Color.secondary.opacity(0.045)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var foundationCanvas: some View {
        VStack(alignment: .leading, spacing: 20) {
            studioHero

            LazyVGrid(columns: columns, spacing: 18) {
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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var studioHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Writing Studio")
                .font(.system(size: 28, weight: .bold))
            Text("Build your piece from premise to sources, then capture snapshots as you refine each draft.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                WorkspacePill(icon: "lightbulb", text: "Premise")
                WorkspacePill(icon: "person.2", text: "Audience")
                WorkspacePill(icon: "list.bullet.rectangle", text: "Outline")
                WorkspacePill(icon: "books.vertical", text: "Sources")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.1),
                            Color.secondary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var draftsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Draft History")
                    .font(.system(size: 12, weight: .semibold))
                WorkspacePill(icon: "doc.plaintext", text: "\(article.drafts.count) drafts")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if sortedDrafts.isEmpty {
                        Text("No snapshots yet. Save one from the toolbar.")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(sortedDrafts) { draft in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(draft.title)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(draft.wordCount) words")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.09))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
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
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.system(size: 13))
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

    // MARK: - Existing actions

    private func importDocument() {
        Task { @MainActor in
            guard let text = await DocumentIngestionService.pickAndExtract() else {
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
