//
//  ArticleBodyMutationAdapter.swift
//  WriteVibe
//

import Foundation

struct ArticleBodyMutationRequest: Equatable {
    /// "append" or "insert"
    let operation: String
    /// "heading" or "paragraph"; required for insert.
    let blockType: String?
    /// 1-based index into body blocks (excludes the H1 title block); required for insert.
    let index: Int?
    let value: String
}

struct ArticleBodyMutationResult: Equatable {
    let operation: String
    let blockCount: Int
}

struct ArticleBodyMutationError: Error, Equatable {
    let code: String
    let message: String
    let hint: String
}

@MainActor
final class ArticleBodyMutationAdapter {

    func apply(
        _ request: ArticleBodyMutationRequest,
        to article: Article
    ) -> Result<ArticleBodyMutationResult, ArticleBodyMutationError> {
        switch request.operation {
        case "append":
            return performAppend(request, article: article)

        case "insert":
            return performInsert(request, article: article)

        default:
            return .failure(ArticleBodyMutationError(
                code: "CMD-004-UNKNOWN_VERB",
                message: "Unknown body operation '\(request.operation)'.",
                hint: "Use append or insert"
            ))
        }
    }

    // MARK: Private

    private func performAppend(
        _ request: ArticleBodyMutationRequest,
        article: Article
    ) -> Result<ArticleBodyMutationResult, ArticleBodyMutationError> {
        let nextPosition = (article.sortedBlocks.last?.position ?? -1) + 1
        let block = ArticleBlock(type: .paragraph, content: request.value, position: nextPosition)
        article.blocks.append(block)
        article.updatedAt = Date()
        return .success(ArticleBodyMutationResult(operation: "append", blockCount: article.blocks.count))
    }

    private func performInsert(
        _ request: ArticleBodyMutationRequest,
        article: Article
    ) -> Result<ArticleBodyMutationResult, ArticleBodyMutationError> {
        guard let blockTypeStr = request.blockType,
              ["heading", "paragraph"].contains(blockTypeStr) else {
            return .failure(ArticleBodyMutationError(
                code: "CMD-005-MISSING_ARGUMENT",
                message: "Invalid block type for body insert. Must be heading or paragraph.",
                hint: "Usage: /article body insert <heading|paragraph> <index> <value>"
            ))
        }
        guard let index = request.index, index >= 1 else {
            return .failure(ArticleBodyMutationError(
                code: "CMD-007-INVALID_INDEX",
                message: "Index must be a 1-based positive integer.",
                hint: "Use a 1-based positive index"
            ))
        }

        let bodyBlocks = article.bodyBlocks
        // Allow insertion up to count+1 so blocks can be appended past the end
        guard index <= bodyBlocks.count + 1 else {
            return .failure(ArticleBodyMutationError(
                code: "CMD-007-INVALID_INDEX",
                message: "Index \(index) is out of range. Article body has \(bodyBlocks.count) block(s).",
                hint: "Use a 1-based index within the body block count or one past the end"
            ))
        }

        let blockType: BlockType = blockTypeStr == "heading" ? .heading(level: 2) : .paragraph

        let insertPosition: Int
        if index <= bodyBlocks.count {
            let targetBlock = bodyBlocks[index - 1]
            insertPosition = targetBlock.position
            // Shift existing blocks at or after the insertion point to make room
            for block in article.blocks where block.position >= insertPosition {
                block.position += 1
            }
        } else {
            // Insert after the last block
            insertPosition = (article.sortedBlocks.last?.position ?? -1) + 1
        }

        let newBlock = ArticleBlock(type: blockType, content: request.value, position: insertPosition)
        article.blocks.append(newBlock)
        article.updatedAt = Date()
        return .success(ArticleBodyMutationResult(operation: "insert", blockCount: article.blocks.count))
    }
}
