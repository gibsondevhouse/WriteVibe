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

    var showEdits = true
    var isRequestingEdits = false
    var editSummary: String? = nil
    var aiError: RuntimeIssue? = nil

    private let editOrchestrator: ArticleEditOrchestrating

    init(editOrchestrator: ArticleEditOrchestrating? = nil) {
        self.editOrchestrator = editOrchestrator ?? DefaultArticleEditOrchestrator()
    }

    var blockChanges: BlockChanges {
        guard let orchestrator = editOrchestrator as? DefaultArticleEditOrchestrator else {
            return [:]
        }
        return orchestrator.blockChanges
    }

    var hasPendingChanges: Bool {
        editOrchestrator.hasPendingChanges
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

    // MARK: Outline insertion

    /// Inserts an `ArticleOutline` produced by Apple Intelligence as heading + paragraph block pairs.
    func insertOutlineBlocks(_ outline: ArticleOutline, into article: Article) {
        var position = (article.sortedBlocks.last?.position ?? 0) + 1000
        for section in outline.sections {
            let headingBlock = ArticleBlock(type: .heading(level: 2), content: section.heading, position: position)
            article.blocks.append(headingBlock)
            position += 1000
            let bodyBlock = ArticleBlock(type: .paragraph, content: section.summary, position: position)
            article.blocks.append(bodyBlock)
            position += 1000
        }
        article.updatedAt = Date()
    }

    // MARK: AI edit request

    func requestAIEdits(for article: Article, defaultModel: AIModel) {
        guard !isRequestingEdits else { return }
        aiError = nil
        isRequestingEdits = true
        let modelID = defaultModel.openRouterModelID ?? "anthropic/claude-3-7-sonnet"

        Task {
            do {
                let applyResult = try await editOrchestrator.requestAndApplyEdits(
                    article: article,
                    modelID: modelID,
                    existingChanges: blockChanges
                )
                editSummary = applyResult.summary
            } catch let error as WriteVibeError {
                aiError = error.runtimeIssue
            } catch {
                aiError = .articleEditFailure(error.localizedDescription)
            }
            isRequestingEdits = false
        }
    }

    // MARK: Accept / Reject (delegated to orchestrator)

    func acceptSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        editOrchestrator.acceptSpan(span, in: block.id, article: article)
    }

    func rejectSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        editOrchestrator.rejectSpan(span, in: block.id, article: article)
    }

    func acceptAllChanges() {
        editOrchestrator.acceptAllChanges()
    }

    func rejectAllChanges(for article: Article) {
        editOrchestrator.rejectAllChanges(for: article)
    }
}

