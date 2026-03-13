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

    // Change tracking
    @State private var blockChanges: BlockChanges = [:]
    @State private var baseline: BaselineDocument? = nil
    @State private var showEdits = true

    // AI state
    @State private var isRequestingEdits = false
    @State private var editSummary: String? = nil
    @State private var aiErrorMessage: String? = nil

    private var sortedBlocks: [ArticleBlock] {
        article.blocks.sorted { $0.position < $1.position }
    }

    private var hasPendingChanges: Bool {
        blockChanges.values.contains { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            editorToolbar
            Divider()
            if hasPendingChanges, let summary = editSummary {
                reviewBanner(summary)
                Divider()
            }
            if let errorMsg = aiErrorMessage {
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
            if hasPendingChanges {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showEdits.toggle() }
                } label: {
                    Label(
                        showEdits ? "Hide Edits" : "Show Edits",
                        systemImage: showEdits ? "eye.slash" : "eye"
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Accept all
                Button { acceptAllChanges() } label: {
                    Label("Accept All", systemImage: "checkmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                // Reject all
                Button { rejectAllChanges() } label: {
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
                requestAIEdits()
            } label: {
                if isRequestingEdits {
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
            .disabled(isRequestingEdits || sortedBlocks.isEmpty)
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
            Button("Dismiss") { aiErrorMessage = nil }
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
            Button("Paragraph")      { addBlock(type: .paragraph) }
            Divider()
            Button("Heading 1")      { addBlock(type: .heading(level: 1)) }
            Button("Heading 2")      { addBlock(type: .heading(level: 2)) }
            Button("Heading 3")      { addBlock(type: .heading(level: 3)) }
            Button("Heading 4")      { addBlock(type: .heading(level: 4)) }
            Divider()
            Button("Block Quote")    { addBlock(type: .blockquote) }
            Button("Code Block")     { addBlock(type: .code(language: nil)) }
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
                ForEach(sortedBlocks) { block in
                    BlockRowView(
                        block: block,
                        spans: showEdits ? (blockChanges[block.id] ?? []) : [],
                        showEdits: showEdits,
                        onAccept: { span in acceptSpan(span, in: block) },
                        onReject: { span in rejectSpan(span, in: block) },
                        onReturnAtEnd: { addBlock(type: .paragraph, after: block) },
                        onDeleteEmpty: { deleteBlockIfEmpty(block) }
                    )
                    .padding(.horizontal, 2)
                }
            }
            .padding(48)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Block management

    private func addBlock(type: BlockType, after preceding: ArticleBlock? = nil) {
        let nextPosition: Int
        if let prec = preceding {
            nextPosition = prec.position + 10
        } else {
            nextPosition = (sortedBlocks.last?.position ?? 0) + 1000
        }
        let block = ArticleBlock(type: type, content: "", position: nextPosition)
        article.blocks.append(block)
        article.updatedAt = Date()
    }

    private func deleteBlockIfEmpty(_ block: ArticleBlock) {
        guard block.content.isEmpty else { return }
        // Never delete the last block
        guard sortedBlocks.count > 1 else { return }
        if let idx = article.blocks.firstIndex(where: { $0.id == block.id }) {
            article.blocks.remove(at: idx)
            article.updatedAt = Date()
        }
    }

    // MARK: - AI edit request

    private func requestAIEdits() {
        guard !isRequestingEdits else { return }
        aiErrorMessage = nil
        isRequestingEdits = true
        // Capture the current state as the baseline before applying edits
        baseline = BaselineDocument(blocks: sortedBlocks)
        let currentBlocks = sortedBlocks
        let modelID = appState.defaultModel.openRouterModelID ?? "anthropic/claude-3-7-sonnet"

        Task {
            do {
                let proposed = try await ArticleAIService.proposeEdits(
                    blocks: currentBlocks,
                    modelID: modelID
                )
                applyProposedEdits(proposed, blocks: currentBlocks)
                editSummary = proposed.summary
            } catch OpenRouterError.missingAPIKey {
                aiErrorMessage = "No OpenRouter API key. Add one in Settings → Cloud API Keys."
            } catch {
                aiErrorMessage = error.localizedDescription
            }
            isRequestingEdits = false
        }
    }

    // MARK: - Apply structured operations → generate ChangeSpans

    private func applyProposedEdits(_ proposed: ProposedEdits, blocks: [ArticleBlock]) {
        var newChanges = blockChanges
        let blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        for op in proposed.operations {
            switch op {
            case let .replace(blockID, range, newText, reason):
                guard let block = blockMap[blockID] else { continue }
                let original = String(block.content[range])
                // Apply the edit to the block's content
                block.content.replaceSubrange(range, with: newText)
                // Find the new range of the inserted text
                if let newRange = block.content.range(of: newText) {
                    let span = ChangeSpan(
                        id: UUID(), changeType: .replace, author: .ai,
                        timestamp: Date(), reason: reason,
                        proposedRange: newRange, originalText: original, proposedText: newText
                    )
                    newChanges[blockID, default: []].append(span)
                }
                article.updatedAt = Date()

            case let .insert(blockID, at, text, reason):
                guard let block = blockMap[blockID] else { continue }
                let safeAt = at <= block.content.endIndex ? at : block.content.endIndex
                block.content.insert(contentsOf: text, at: safeAt)
                let end = block.content.index(safeAt, offsetBy: text.count,
                                              limitedBy: block.content.endIndex) ?? block.content.endIndex
                let span = ChangeSpan(
                    id: UUID(), changeType: .insert, author: .ai,
                    timestamp: Date(), reason: reason,
                    proposedRange: safeAt..<end, originalText: nil, proposedText: text
                )
                newChanges[blockID, default: []].append(span)
                article.updatedAt = Date()

            case let .delete(blockID, range, reason):
                guard let block = blockMap[blockID] else { continue }
                let original = String(block.content[range])
                // For deletes, record the span at the range before removing it
                let anchor = range.lowerBound
                let emptyRange = anchor..<anchor
                let span = ChangeSpan(
                    id: UUID(), changeType: .delete, author: .ai,
                    timestamp: Date(), reason: reason,
                    proposedRange: emptyRange, originalText: original, proposedText: nil
                )
                newChanges[blockID, default: []].append(span)
                block.content.removeSubrange(range)
                article.updatedAt = Date()

            case let .insertBlock(afterBlockID, type, content, _):
                if let after = blockMap[afterBlockID] {
                    addBlock(type: type, after: after)
                    article.blocks.last?.content = content
                }

            case let .deleteBlock(blockID, _):
                if let block = blockMap[blockID] {
                    deleteBlockIfEmpty(block)
                }
            }
        }
        blockChanges = newChanges
    }

    // MARK: - Accept / Reject

    private func acceptSpan(_ span: ChangeSpan, in block: ArticleBlock) {
        // Accepting: proposed text is already in the block — just remove the span
        blockChanges[block.id]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }

    private func rejectSpan(_ span: ChangeSpan, in block: ArticleBlock) {
        // Revert the block content using DiffEngine
        block.content = DiffEngine.rejectedText(current: block.content, span: span)
        blockChanges[block.id]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }

    private func acceptAllChanges() {
        blockChanges.removeAll()
        clearEditStateIfDone()
    }

    private func rejectAllChanges() {
        guard let base = baseline else { return }
        for block in article.blocks {
            if let originalText = base.text[block.id] {
                block.content = originalText
            }
        }
        blockChanges.removeAll()
        clearEditStateIfDone()
    }

    private func clearEditStateIfDone() {
        if !hasPendingChanges {
            editSummary = nil
            baseline = nil
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
