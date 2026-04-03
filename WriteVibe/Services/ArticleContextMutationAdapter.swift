//
//  ArticleContextMutationAdapter.swift
//  WriteVibe
//

import Foundation

struct ArticleContextMutationRequest: Equatable {
    let field: String
    let value: String
}

struct ArticleContextMutationResult: Equatable {
    let field: String
    let storedValue: String
}

struct ArticleContextMutationError: Error, Equatable {
    let code: String
    let message: String
    let hint: String
}

@MainActor
final class ArticleContextMutationAdapter {
    typealias Validation = (String) -> Result<String, ArticleContextMutationError>
    typealias Apply = (Article, String) -> Void

    private struct MatrixEntry {
        let validation: Validation
        let apply: Apply
    }

    static let supportedFields: Set<String> = Set(fieldAliases.keys)

    func validate(field rawField: String, value rawValue: String) -> Result<ArticleContextMutationRequest, ArticleContextMutationError> {
        let normalizedField = rawField.lowercased()

        guard let canonicalField = Self.fieldAliases[normalizedField],
              let entry = Self.matrix[canonicalField] else {
            return .failure(ArticleContextMutationError(
                code: "CMD-008-UNKNOWN_FIELD",
                message: "Unknown field '\(rawField)'.",
                hint: "Use /article help for valid fields"
            ))
        }

        switch entry.validation(rawValue) {
        case .success(let normalizedValue):
            return .success(ArticleContextMutationRequest(field: canonicalField, value: normalizedValue))
        case .failure(let error):
            return .failure(error)
        }
    }

    func apply(_ request: ArticleContextMutationRequest, to article: Article) -> Result<ArticleContextMutationResult, ArticleContextMutationError> {
        guard let entry = Self.matrix[request.field] else {
            return .failure(ArticleContextMutationError(
                code: "CMD-008-UNKNOWN_FIELD",
                message: "Unknown field '\(request.field)'.",
                hint: "Use /article help for valid fields"
            ))
        }

        entry.apply(article, request.value)
        article.updatedAt = Date()
        return .success(ArticleContextMutationResult(field: request.field, storedValue: Self.storedValue(for: request.field, article: article)))
    }

    private static let fieldAliases: [String: String] = [
        "title": "title",
        "subtitle": "subtitle",
        "topic": "topic",
        "audience": "audience",
        "quicknotes": "quicknotes",
        "sourcelinks": "sourcelinks",
        "sourcelink": "sourcelinks",
        "sourceLinks": "sourcelinks",
        "outline": "outline",
        "summary": "summary",
        "purpose": "purpose",
        "style": "style",
        "keytakeaway": "keytakeaway",
        "publishingintent": "publishingintent",
        "tone": "tone",
        "length": "targetlength",
        "targetlength": "targetlength"
    ]

    private static let matrix: [String: MatrixEntry] = [
        "title": MatrixEntry(validation: nonEmptyValue(fieldName: "title")) { article, value in
            article.title = value
            if let titleBlock = article.sortedBlocks.first(where: { $0.blockType == .heading(level: 1) && $0.position == 0 }) {
                titleBlock.content = value
            }
        },
        "subtitle": MatrixEntry(validation: passthrough) { article, value in
            article.subtitle = value
        },
        "topic": MatrixEntry(validation: passthrough) { article, value in
            article.topic = value
        },
        "audience": MatrixEntry(validation: passthrough) { article, value in
            article.audience = value
        },
        "quicknotes": MatrixEntry(validation: passthrough) { article, value in
            article.quickNotes = value
        },
        "sourcelinks": MatrixEntry(validation: passthrough) { article, value in
            article.sourceLinks = value
        },
        "outline": MatrixEntry(validation: passthrough) { article, value in
            article.outline = value
        },
        "summary": MatrixEntry(validation: passthrough) { article, value in
            article.summary = value
        },
        "purpose": MatrixEntry(validation: passthrough) { article, value in
            article.purpose = value
        },
        "style": MatrixEntry(validation: passthrough) { article, value in
            article.style = value
        },
        "keytakeaway": MatrixEntry(validation: passthrough) { article, value in
            article.keyTakeaway = value
        },
        "publishingintent": MatrixEntry(validation: passthrough) { article, value in
            article.publishingIntent = value
        },
        "tone": MatrixEntry(validation: toneValue) { article, value in
            article.tone = ArticleTone(rawValue: value) ?? .conversational
        },
        "targetlength": MatrixEntry(validation: targetLengthValue) { article, value in
            article.targetLength = ArticleLength(rawValue: value) ?? .medium
        }
    ]

    private static func storedValue(for field: String, article: Article) -> String {
        switch field {
        case "title":
            return article.title
        case "subtitle":
            return article.subtitle
        case "topic":
            return article.topic
        case "audience":
            return article.audience
        case "quicknotes":
            return article.quickNotes
        case "sourcelinks":
            return article.sourceLinks
        case "outline":
            return article.outline
        case "summary":
            return article.summary
        case "purpose":
            return article.purpose
        case "style":
            return article.style
        case "keytakeaway":
            return article.keyTakeaway
        case "publishingintent":
            return article.publishingIntent
        case "tone":
            return article.tone.rawValue
        case "targetlength":
            return article.targetLength.rawValue
        default:
            return ""
        }
    }

    private static let passthrough: Validation = { .success($0) }

    private static func nonEmptyValue(fieldName: String) -> Validation {
        { value in
            let trimmed = value.trimmed
            guard !trimmed.isEmpty else {
                return .failure(ArticleContextMutationError(
                    code: "CMD-011-VALIDATION_FAILED",
                    message: "Invalid value for field '\(fieldName)': value cannot be empty.",
                    hint: "Provide a non-empty \(fieldName) value"
                ))
            }
            return .success(trimmed)
        }
    }

    private static func toneValue(_ value: String) -> Result<String, ArticleContextMutationError> {
        let trimmed = value.trimmed
        guard let tone = ArticleTone.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return .failure(ArticleContextMutationError(
                code: "CMD-011-VALIDATION_FAILED",
                message: "Invalid value for field 'tone': '\(value)'.",
                hint: "Use one of: \(ArticleTone.allCases.map(\.rawValue).joined(separator: ", "))"
            ))
        }
        return .success(tone.rawValue)
    }

    private static func targetLengthValue(_ value: String) -> Result<String, ArticleContextMutationError> {
        let trimmed = value.trimmed
        guard let length = ArticleLength.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return .failure(ArticleContextMutationError(
                code: "CMD-011-VALIDATION_FAILED",
                message: "Invalid value for field 'targetlength': '\(value)'.",
                hint: "Use one of: \(ArticleLength.allCases.map(\.rawValue).joined(separator: ", "))"
            ))
        }
        return .success(length.rawValue)
    }
}