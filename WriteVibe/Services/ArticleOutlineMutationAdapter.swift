//
//  ArticleOutlineMutationAdapter.swift
//  WriteVibe
//

import Foundation

struct ArticleOutlineMutationRequest: Equatable {
    /// "append" or "replace"
    let operation: String
    /// 1-based line index; required for replace.
    let index: Int?
    let value: String
}

struct ArticleOutlineMutationResult: Equatable {
    let operation: String
    let lineCount: Int
}

struct ArticleOutlineMutationError: Error, Equatable {
    let code: String
    let message: String
    let hint: String
}

@MainActor
final class ArticleOutlineMutationAdapter {

    func apply(
        _ request: ArticleOutlineMutationRequest,
        to article: Article
    ) -> Result<ArticleOutlineMutationResult, ArticleOutlineMutationError> {
        switch request.operation {
        case "append":
            let current = article.outline.trimmingCharacters(in: .whitespacesAndNewlines)
            article.outline = current.isEmpty ? request.value : current + "\n" + request.value
            article.updatedAt = Date()
            let lineCount = countLines(article.outline)
            return .success(ArticleOutlineMutationResult(operation: "append", lineCount: lineCount))

        case "replace":
            guard let index = request.index, index >= 1 else {
                return .failure(ArticleOutlineMutationError(
                    code: "CMD-007-INVALID_INDEX",
                    message: "Index must be a 1-based positive integer.",
                    hint: "Use a 1-based positive index"
                ))
            }
            var lines = article.outline.components(separatedBy: "\n")
            guard index <= lines.count else {
                return .failure(ArticleOutlineMutationError(
                    code: "CMD-007-INVALID_INDEX",
                    message: "Index \(index) is out of range. Outline has \(lines.count) line(s).",
                    hint: "Use a 1-based index within the current outline line count"
                ))
            }
            lines[index - 1] = request.value
            article.outline = lines.joined(separator: "\n")
            article.updatedAt = Date()
            return .success(ArticleOutlineMutationResult(operation: "replace", lineCount: lines.count))

        default:
            return .failure(ArticleOutlineMutationError(
                code: "CMD-004-UNKNOWN_VERB",
                message: "Unknown outline operation '\(request.operation)'.",
                hint: "Use append or replace"
            ))
        }
    }

    private func countLines(_ text: String) -> Int {
        text.isEmpty ? 0 : text.components(separatedBy: "\n").count
    }
}
