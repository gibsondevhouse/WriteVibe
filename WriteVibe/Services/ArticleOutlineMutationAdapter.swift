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

    func applyStructuredWorkflowSuggestion(
        _ proposal: AppleStructuredOutlineSuggestionProposal,
        to article: Article
    ) -> Result<ArticleOutlineMutationResult, ArticleOutlineMutationError> {
        guard proposal.applyMode == .replaceOutlineText else {
            return .failure(ArticleOutlineMutationError(
                code: "CMD-012-UNSUPPORTED_OUTLINE_APPLY_MODE",
                message: "Only outline text replacement is supported for this Apple workflow slice.",
                hint: "Use replaceOutlineText for structured outline suggestions"
            ))
        }

        let sections = proposal.sections.filter {
            !$0.heading.trimmed.isEmpty || !$0.summary.trimmed.isEmpty
        }
        guard !sections.isEmpty else {
            return .failure(ArticleOutlineMutationError(
                code: "CMD-011-VALIDATION_FAILED",
                message: "Outline suggestion did not include any sections.",
                hint: "Retry the outline suggestion with a clearer title or topic"
            ))
        }

        article.outline = formattedOutlineText(from: sections)
        article.updatedAt = Date()
        return .success(ArticleOutlineMutationResult(operation: "replaceOutlineText", lineCount: countLines(article.outline)))
    }

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

    private func formattedOutlineText(from sections: [AppleStructuredOutlineSectionProposal]) -> String {
        sections.enumerated().map { index, section in
            let headingLine = "\(index + 1). \(section.heading.trimmed)"
            let summaryLine = section.summary.trimmed.isEmpty ? nil : "   \(section.summary.trimmed)"
            return [headingLine, summaryLine].compactMap { $0 }.joined(separator: "\n")
        }
        .joined(separator: "\n")
    }
}
