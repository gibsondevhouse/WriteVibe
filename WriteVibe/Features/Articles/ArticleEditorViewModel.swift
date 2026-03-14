//
//  ArticleEditorViewModel.swift
//  WriteVibe
//

import Foundation
import SwiftUI

// MARK: - ArticleEditorViewModel

@MainActor
@Observable
final class ArticleEditorViewModel {

    var blockChanges: BlockChanges = [:]
    var showEdits = true
    var isRequestingEdits = false
    var editSummary: String? = nil
    var aiErrorMessage: String? = nil

    private var baseline: BaselineDocument? = nil

    var hasPendingChanges: Bool {
        blockChanges.values.contains { !$0.isEmpty }
    }

    // MARK: Block management

    func addBlock(type: BlockType, to article: Article, after preceding: ArticleBlock? = nil) {
        let nextPosition: Int
        if let prec = preceding {
            nextPosition = prec.position + 10
        } else {
            nextPosition = (article.sortedBlocks.last?.position ?? 0) + 1000
        }
        let block = ArticleBlock(type: type, content: "", position: nextPosition)
        article.blocks.append(block)
        article.updatedAt = Date()
    }

    func deleteBlockIfEmpty(_ block: ArticleBlock, from article: Article) {
        guard block.content.isEmpty else { return }
        guard article.blocks.count > 1 else { return }
        if let idx = article.blocks.firstIndex(where: { $0.id == block.id }) {
            article.blocks.remove(at: idx)
            article.updatedAt = Date()
        }
    }

    // MARK: AI edit request

    func requestAIEdits(for article: Article, defaultModel: AIModel) {
        guard !isRequestingEdits else { return }
        aiErrorMessage = nil
        isRequestingEdits = true
        baseline = BaselineDocument(blocks: article.sortedBlocks)
        let currentBlocks = article.sortedBlocks
        let modelID = defaultModel.openRouterModelID ?? "anthropic/claude-3-7-sonnet"

        Task {
            do {
                let proposed = try await ArticleAIService.proposeEdits(blocks: currentBlocks, modelID: modelID)
                applyProposedEdits(proposed, blocks: currentBlocks, article: article)
                editSummary = proposed.summary
            } catch WriteVibeError.missingAPIKey {
                aiErrorMessage = "No OpenRouter API key. Add one in Settings → Cloud API Keys."
            } catch {
                aiErrorMessage = error.localizedDescription
            }
            isRequestingEdits = false
        }
    }

    // MARK: Apply structured edits

    private func applyProposedEdits(_ proposed: ProposedEdits, blocks: [ArticleBlock], article: Article) {
        var newChanges = blockChanges
        let blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        for op in proposed.operations {
            switch op {
            case let .replace(blockID, range, newText, reason):
                guard let block = blockMap[blockID] else { continue }
                let original = String(block.content[range])
                block.content.replaceSubrange(range, with: newText)
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
                    addBlock(type: type, to: article, after: after)
                    article.blocks.last?.content = content
                }

            case let .deleteBlock(blockID, _):
                if let block = blockMap[blockID] {
                    deleteBlockIfEmpty(block, from: article)
                }
            }
        }
        blockChanges = newChanges
    }

    // MARK: Accept / Reject

    func acceptSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        blockChanges[block.id]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }

    func rejectSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        block.content = DiffEngine.rejectedText(current: block.content, span: span)
        blockChanges[block.id]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }

    func acceptAllChanges() {
        blockChanges.removeAll()
        clearEditStateIfDone()
    }

    func rejectAllChanges(for article: Article) {
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
}
