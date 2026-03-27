//
//  ArticleWorkspaceView.swift
//  WriteVibe
//

import SwiftUI

// MARK: - WorkspaceTab

enum WorkspaceTab: String, CaseIterable {
    case writing  = "Writing"
    case context  = "Context"
    case sources  = "Sources"

    var icon: String {
        switch self {
        case .writing: return "square.and.pencil"
        case .context: return "lightbulb"
        case .sources: return "books.vertical"
        }
    }
}

// MARK: - ArticleWorkspaceView

struct ArticleWorkspaceView: View {
    @Bindable var article: Article
    let onBack: () -> Void

    @State private var selectedTab: WorkspaceTab = .writing
    @State private var uploadStatusMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            shellHeader
            Divider()
            tabContent
        }
    }

    // MARK: - Shell Header

    private var shellHeader: some View {
        HStack(spacing: WVSpace.md) {
            Button(action: onBack) {
                HStack(spacing: WVSpace.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Articles")
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            Text(article.title)
                .font(.wvSubhead)
                .lineLimit(1)
                .truncationMode(.tail)

            Menu {
                ForEach(PublishStatus.allCases, id: \.self) { status in
                    Button {
                        article.publishStatus = status
                        article.updatedAt = Date()
                    } label: {
                        Label(status.rawValue, systemImage: status.icon)
                    }
                }
            } label: {
                Label(article.publishStatus.rawValue, systemImage: article.publishStatus.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            tabBar

            Spacer()

            Text("\(article.wordCount) words")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .monospacedDigit()

            Button(action: saveDraftSnapshot) {
                Label("Snapshot", systemImage: "camera")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, WVSpace.xl)
        .padding(.vertical, WVSpace.sm)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(WorkspaceTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: WVSpace.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.rawValue)
                            .font(.wvLabel)
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .padding(.horizontal, WVSpace.md)
                    .padding(.vertical, WVSpace.xs + 2)
                    .background(
                        selectedTab == tab
                            ? Color.primary.opacity(0.06)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: WVRadius.chipLg)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.card))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .writing:
            ArticleEditorView(article: article)
        case .context:
            ArticleContextTab(article: article)
        case .sources:
            ArticleSourcesTab(article: article, onImport: importDocument)
        }
    }

    // MARK: - Status Color

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
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
