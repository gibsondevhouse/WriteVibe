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
            ArticleWorkspaceTopBar(
                article: article,
                onBack: onBack,
                onImport: { importDocument() },
                onSnapshot: { saveDraftSnapshot() },
                onOpenEditor: { isEditingArticle = true }
            )
            Divider()

            HStack(alignment: .top, spacing: 0) {
                ArticleDNAPanel(
                    article: article,
                    uploadStatusMessage: $uploadStatusMessage,
                    onImportDocument: { importDocument() }
                )
                Divider()

                ScrollView {
                    ArticleFoundationCanvas(article: article)
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

    // MARK: - Actions

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
