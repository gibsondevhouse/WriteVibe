//
//  ArticleEditorView.swift
//  WriteVibe
//
//  Block-based article editor with AI edit highlighting and accept/reject review.
//

import SwiftUI
import SwiftData

// MARK: - ArticleEditorView

struct ArticleEditorView: View {
    @Bindable var article: Article
    /// Called when the user navigates back to the dashboard.
    let onBack: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var vm = ArticleEditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            if vm.hasPendingChanges, let summary = vm.editSummary {
                reviewBanner(summary)
                Divider()
            }
            if let errorMsg = vm.aiErrorMessage {
                errorBanner(errorMsg)
                Divider()
            }
            editorCanvas
        }
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Back
            Button { onBack() } label: {
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

            // Status picker
            Menu {
                ForEach(PublishStatus.allCases, id: \.self) { status in
                    Button {
                        article.publishStatus = status
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

            // Word count
            Text("\(article.wordCount) words")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
                .monospacedDigit()

            // Show / hide edits toggle — only relevant when changes exist
            if vm.hasPendingChanges {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { vm.showEdits.toggle() }
                } label: {
                    Label(
                        vm.showEdits ? "Hide Edits" : "Show Edits",
                        systemImage: vm.showEdits ? "eye.slash" : "eye"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Accept all
                Button { vm.acceptAllChanges() } label: {
                    Label("Accept All", systemImage: "checkmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Reject all
                Button { vm.rejectAllChanges(for: article) } label: {
                    Label("Reject All", systemImage: "xmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider().frame(height: 16)

            // Block type inserter
            blockInserterMenu

            Divider().frame(height: 16)

            // AI edit button
            Button {
                vm.requestAIEdits(for: article, defaultModel: appState.defaultModel)
            } label: {
                if vm.isRequestingEdits {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .frame(width: 60)
                } else {
                    Label("AI Edit", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(vm.isRequestingEdits || article.sortedBlocks.isEmpty)
            .help("Ask AI to propose edits to this article")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Review banner

    private func reviewBanner(_ summary: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.06))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") { vm.aiErrorMessage = nil }
                .font(.system(size: 11))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.07))
    }

    // MARK: - Block inserter menu

    private var blockInserterMenu: some View {
        Menu {
            Button("Paragraph")      { vm.addBlock(type: .paragraph, to: article) }
            Divider()
            Button("Heading 1")      { vm.addBlock(type: .heading(level: 1), to: article) }
            Button("Heading 2")      { vm.addBlock(type: .heading(level: 2), to: article) }
            Button("Heading 3")      { vm.addBlock(type: .heading(level: 3), to: article) }
            Button("Heading 4")      { vm.addBlock(type: .heading(level: 4), to: article) }
            Divider()
            Button("Block Quote")    { vm.addBlock(type: .blockquote, to: article) }
            Button("Code Block")     { vm.addBlock(type: .code(language: nil), to: article) }
        } label: {
            Label("Add Block", systemImage: "plus.rectangle.on.rectangle")
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Canvas

    private var editorCanvas: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(article.sortedBlocks) { block in
                    BlockRowView(
                        block: block,
                        spans: vm.showEdits ? (vm.blockChanges[block.id] ?? []) : [],
                        showEdits: vm.showEdits,
                        onAccept: { span in vm.acceptSpan(span, in: block, article: article) },
                        onReject: { span in vm.rejectSpan(span, in: block, article: article) },
                        onReturnAtEnd: { vm.addBlock(type: .paragraph, to: article, after: block) },
                        onDeleteEmpty: { vm.deleteBlockIfEmpty(block, from: article) }
                    )
                    .padding(.horizontal, 2)
                }
            }
            .padding(48)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status colour

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}
