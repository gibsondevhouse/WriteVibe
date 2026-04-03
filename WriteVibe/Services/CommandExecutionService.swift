//
//  CommandExecutionService.swift
//  WriteVibe
//

import Foundation
import SwiftData

enum CommandErrorCategory: String, Codable {
    case parse
    case validation
    case domain
    case state
    case execution
}

struct CommandEnvelopeCommand: Codable, Equatable, Sendable {
    let namespace: String
    let verb: String?
    let subverb: String?
    let raw: String

    nonisolated static func == (lhs: CommandEnvelopeCommand, rhs: CommandEnvelopeCommand) -> Bool {
        lhs.namespace == rhs.namespace
            && lhs.verb == rhs.verb
            && lhs.subverb == rhs.subverb
            && lhs.raw == rhs.raw
    }
}

struct CommandEnvelopeTarget: Codable, Equatable, Sendable {
    let articleId: String?
    let articleTitle: String?
    let scope: String?

    nonisolated static func == (lhs: CommandEnvelopeTarget, rhs: CommandEnvelopeTarget) -> Bool {
        lhs.articleId == rhs.articleId
            && lhs.articleTitle == rhs.articleTitle
            && lhs.scope == rhs.scope
    }
}

struct CommandEnvelopeResult: Codable, Equatable, Sendable {
    let summary: String
    let nextSuggestedCommand: String?

    nonisolated static func == (lhs: CommandEnvelopeResult, rhs: CommandEnvelopeResult) -> Bool {
        lhs.summary == rhs.summary
            && lhs.nextSuggestedCommand == rhs.nextSuggestedCommand
    }
}

struct CommandEnvelopeArticleMutation: Codable, Equatable, Sendable {
    let field: String
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeArticleMutation, rhs: CommandEnvelopeArticleMutation) -> Bool {
        lhs.field == rhs.field
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeOutlineOperation: Codable, Equatable, Sendable {
    /// "append" or "replace"
    let operation: String
    /// 1-based line index; present for replace only.
    let index: Int?
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeOutlineOperation, rhs: CommandEnvelopeOutlineOperation) -> Bool {
        lhs.operation == rhs.operation
            && lhs.index == rhs.index
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeBodyOperation: Codable, Equatable, Sendable {
    /// "append" or "insert"
    let operation: String
    /// "heading" or "paragraph"; present for insert only.
    let blockType: String?
    /// 1-based body-block index; present for insert only.
    let index: Int?
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeBodyOperation, rhs: CommandEnvelopeBodyOperation) -> Bool {
        lhs.operation == rhs.operation
            && lhs.blockType == rhs.blockType
            && lhs.index == rhs.index
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeError: Codable, Equatable, Sendable {
    let code: String
    let category: CommandErrorCategory
    let message: String
    let recoverable: Bool
    let hint: String

    nonisolated static func == (lhs: CommandEnvelopeError, rhs: CommandEnvelopeError) -> Bool {
        lhs.code == rhs.code
            && lhs.category == rhs.category
            && lhs.message == rhs.message
            && lhs.recoverable == rhs.recoverable
            && lhs.hint == rhs.hint
    }
}

struct CommandExecutionEnvelope: Codable, Equatable, Error, Sendable {
    let ok: Bool
    let requestId: String
    let timestamp: String
    let command: CommandEnvelopeCommand
    let target: CommandEnvelopeTarget?
    let result: CommandEnvelopeResult?
    let error: CommandEnvelopeError?
    let draftAction: String?  // e.g., "start", "set:field=value", "create", "cancel"
    let articleMutation: CommandEnvelopeArticleMutation?
    let outlineOperation: CommandEnvelopeOutlineOperation?
    let bodyOperation: CommandEnvelopeBodyOperation?

    nonisolated static func == (lhs: CommandExecutionEnvelope, rhs: CommandExecutionEnvelope) -> Bool {
        lhs.ok == rhs.ok
            && lhs.requestId == rhs.requestId
            && lhs.timestamp == rhs.timestamp
            && lhs.command == rhs.command
            && lhs.target == rhs.target
            && lhs.result == rhs.result
            && lhs.error == rhs.error
            && lhs.draftAction == rhs.draftAction
            && lhs.articleMutation == rhs.articleMutation
            && lhs.outlineOperation == rhs.outlineOperation
            && lhs.bodyOperation == rhs.bodyOperation
    }

    func renderForAssistantMessage() -> String {
        if ok {
            var lines = [result?.summary ?? "Command completed."]
            if let next = result?.nextSuggestedCommand, !next.isEmpty {
                lines.append("Next: \(next)")
            }
            return lines.joined(separator: "\n")
        }

        var lines = [error?.message ?? "I couldn't complete that command."]
        if let hint = error?.hint.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            lines.append("Try: \(hint)")
        }
        return lines.joined(separator: "\n")
    }
}

enum CommandDispatchOutcome {
    case notACommand
    case handled(CommandExecutionEnvelope)
}

private struct ParsedArticleCommand {
    let verb: String
    let subverb: String?
    let argumentText: String?
}

@MainActor
final class CommandExecutionService {
    private let isoFormatter = ISO8601DateFormatter()

    /// Represents minimal draft session context for command validation.
    struct DraftContext {
        let isActive: Bool
        let draftFields: [String: String]
    }

    struct ArticleContext {
        let hasSelection: Bool
        let articleId: String?
        let articleTitle: String?
    }

    func dispatch(
        input rawInput: String,
        conversationId: UUID,
        context: ModelContext,
        draftContext: DraftContext? = nil,
        articleContext: ArticleContext? = nil
    ) -> CommandDispatchOutcome {
        _ = context

        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return .handled(errorEnvelope(
                code: "CMD-001-EMPTY_INPUT",
                category: .parse,
                message: "Command input is empty.",
                hint: "Try /article help",
                raw: rawInput,
                namespace: "article",
                verb: nil,
                subverb: nil
            ))
        }

        guard raw.hasPrefix("/") else {
            return .notACommand
        }

        let commandWithoutSlash = String(raw.dropFirst())
        let namespace = commandWithoutSlash.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init)?.lowercased() ?? ""

        if namespace != "article" {
            if ["script", "scripts", "email", "emails"].contains(namespace) {
                return .handled(errorEnvelope(
                    code: "CMD-013-DOMAIN_BOUNDARY_REJECTED",
                    category: .domain,
                    message: "This app only supports article commands.",
                    hint: "This app only supports article commands",
                    raw: raw,
                    namespace: namespace.isEmpty ? "unknown" : namespace,
                    verb: nil,
                    subverb: nil
                ))
            }

            return .handled(errorEnvelope(
                code: "CMD-003-UNKNOWN_NAMESPACE",
                category: .domain,
                message: "Only /article commands are supported in this app.",
                hint: "Only /article commands are supported in this app",
                raw: raw,
                namespace: namespace.isEmpty ? "unknown" : namespace,
                verb: nil,
                subverb: nil
            ))
        }

        let tail = commandWithoutSlash.dropFirst(namespace.count)
        switch parseArticleCommand(String(tail)) {
        case .failure(let envelope):
            return .handled(envelope)
        case .success(let parsed):
            return .handled(dispatchArticle(parsed, raw: raw, conversationId: conversationId, draftContext: draftContext, articleContext: articleContext))
        }
    }

    private func parseArticleCommand(_ tail: String) -> Result<ParsedArticleCommand, CommandExecutionEnvelope> {
        switch tokenize(tail) {
        case .failure(let error):
            return .failure(error)
        case .success(let tokens):
            guard let verb = tokens.first?.lowercased() else {
                return .failure(errorEnvelope(
                    code: "CMD-004-UNKNOWN_VERB",
                    category: .parse,
                    message: "Unknown article command.",
                    hint: "Try /article help",
                    raw: "/article",
                    namespace: "article",
                    verb: nil,
                    subverb: nil
                ))
            }

            switch verb {
            case "help", "new", "cancel":
                guard tokens.count == 1 else {
                    return .failure(errorEnvelope(
                        code: "CMD-005-MISSING_ARGUMENT",
                        category: .validation,
                        message: "Unexpected arguments for /article \(verb).",
                        hint: "Usage: /article \(verb)",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: verb,
                        subverb: nil
                    ))
                }
                return .success(ParsedArticleCommand(verb: verb, subverb: nil, argumentText: nil))

            case "create":
                let inferredCreateText: String?
                if tokens.count > 1 {
                    let text = tokens.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    inferredCreateText = text.isEmpty ? nil : text
                } else {
                    inferredCreateText = nil
                }
                return .success(ParsedArticleCommand(verb: verb, subverb: nil, argumentText: inferredCreateText))

            case "set", "update":
                guard tokens.count >= 3 else {
                    return .failure(errorEnvelope(
                        code: "CMD-005-MISSING_ARGUMENT",
                        category: .validation,
                        message: "Missing required field or value.",
                        hint: "Usage: /article \(verb) <field> <value>",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: verb,
                        subverb: nil
                    ))
                }

                let field = tokens[1].lowercased()
                guard Self.supportedFields.contains(field) else {
                    return .failure(errorEnvelope(
                        code: "CMD-008-UNKNOWN_FIELD",
                        category: .validation,
                        message: "Unknown field '\(tokens[1])'.",
                        hint: "Use /article help for valid fields",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: verb,
                        subverb: nil
                    ))
                }

                return .success(ParsedArticleCommand(verb: verb, subverb: nil, argumentText: nil))

            case "outline":
                guard tokens.count >= 2 else {
                    return .failure(errorEnvelope(
                        code: "CMD-005-MISSING_ARGUMENT",
                        category: .validation,
                        message: "Missing outline operation.",
                        hint: "Usage: /article outline <append|replace> ...",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: "outline",
                        subverb: nil
                    ))
                }

                let subverb = tokens[1].lowercased()
                switch subverb {
                case "append":
                    guard tokens.count >= 3 else {
                        return .failure(errorEnvelope(
                            code: "CMD-005-MISSING_ARGUMENT",
                            category: .validation,
                            message: "Missing outline value.",
                            hint: "Usage: /article outline append <value>",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "outline",
                            subverb: "append"
                        ))
                    }
                case "replace":
                    guard tokens.count >= 4 else {
                        return .failure(errorEnvelope(
                            code: "CMD-005-MISSING_ARGUMENT",
                            category: .validation,
                            message: "Missing outline replace arguments.",
                            hint: "Usage: /article outline replace <index> <value> --confirm",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "outline",
                            subverb: "replace"
                        ))
                    }
                    guard let index = Int(tokens[2]), index >= 1 else {
                        return .failure(errorEnvelope(
                            code: "CMD-007-INVALID_INDEX",
                            category: .validation,
                            message: "Index must be a 1-based positive integer.",
                            hint: "Use a 1-based positive index",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "outline",
                            subverb: "replace"
                        ))
                    }
                    guard tokens.last?.lowercased() == "--confirm" else {
                        return .failure(errorEnvelope(
                            code: "CMD-009-CONFIRMATION_REQUIRED",
                            category: .validation,
                            message: "Outline replace requires explicit confirmation.",
                            hint: "Re-run: /article outline replace \(tokens[2]) \"<value>\" --confirm",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "outline",
                            subverb: "replace"
                        ))
                    }
                default:
                    return .failure(errorEnvelope(
                        code: "CMD-004-UNKNOWN_VERB",
                        category: .parse,
                        message: "Unknown outline command.",
                        hint: "Try /article help",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: "outline",
                        subverb: subverb
                    ))
                }

                return .success(ParsedArticleCommand(verb: "outline", subverb: subverb, argumentText: nil))

            case "body":
                guard tokens.count >= 2 else {
                    return .failure(errorEnvelope(
                        code: "CMD-005-MISSING_ARGUMENT",
                        category: .validation,
                        message: "Missing body operation.",
                        hint: "Usage: /article body <append|insert> ...",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: "body",
                        subverb: nil
                    ))
                }

                let subverb = tokens[1].lowercased()
                switch subverb {
                case "append":
                    guard tokens.count >= 3 else {
                        return .failure(errorEnvelope(
                            code: "CMD-005-MISSING_ARGUMENT",
                            category: .validation,
                            message: "Missing body append value.",
                            hint: "Usage: /article body append <value>",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "body",
                            subverb: "append"
                        ))
                    }
                case "insert":
                    guard tokens.count >= 5 else {
                        return .failure(errorEnvelope(
                            code: "CMD-005-MISSING_ARGUMENT",
                            category: .validation,
                            message: "Missing body insert arguments.",
                            hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "body",
                            subverb: "insert"
                        ))
                    }
                    let bodyType = tokens[2].lowercased()
                    guard ["heading", "paragraph"].contains(bodyType) else {
                        return .failure(errorEnvelope(
                            code: "CMD-005-MISSING_ARGUMENT",
                            category: .validation,
                            message: "Body insert type must be heading or paragraph.",
                            hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "body",
                            subverb: "insert"
                        ))
                    }
                    guard let index = Int(tokens[3]), index >= 1 else {
                        return .failure(errorEnvelope(
                            code: "CMD-007-INVALID_INDEX",
                            category: .validation,
                            message: "Index must be a 1-based positive integer.",
                            hint: "Use a 1-based positive index",
                            raw: "/article \(tokens.joined(separator: " "))",
                            namespace: "article",
                            verb: "body",
                            subverb: "insert"
                        ))
                    }
                default:
                    return .failure(errorEnvelope(
                        code: "CMD-004-UNKNOWN_VERB",
                        category: .parse,
                        message: "Unknown body command.",
                        hint: "Try /article help",
                        raw: "/article \(tokens.joined(separator: " "))",
                        namespace: "article",
                        verb: "body",
                        subverb: subverb
                    ))
                }

                return .success(ParsedArticleCommand(verb: "body", subverb: subverb, argumentText: nil))

            default:
                return .failure(errorEnvelope(
                    code: "CMD-004-UNKNOWN_VERB",
                    category: .parse,
                    message: "Unknown article command.",
                    hint: "Try /article help",
                    raw: "/article \(tokens.joined(separator: " "))",
                    namespace: "article",
                    verb: verb,
                    subverb: nil
                ))
            }
        }
    }

    private func dispatchArticle(
        _ parsed: ParsedArticleCommand,
        raw: String,
        conversationId: UUID,
        draftContext: DraftContext?,
        articleContext: ArticleContext?
    ) -> CommandExecutionEnvelope {
        if parsed.verb == "help" {
            return successEnvelope(
                raw: raw,
                verb: parsed.verb,
                subverb: parsed.subverb,
                summary: Self.helpSummary,
                nextSuggestedCommand: "/article new",
                target: CommandEnvelopeTarget(
                    articleId: nil,
                    articleTitle: nil,
                    scope: "help"
                )
            )
        }

        // Handle draft lifecycle commands
        switch parsed.verb {
        case "new":
            return handleNew(raw: raw, conversationId: conversationId, draftContext: draftContext)
        case "set", "update":
            return handleSet(raw: raw, verb: parsed.verb, conversationId: conversationId, draftContext: draftContext, articleContext: articleContext)
        case "create":
            return handleCreate(raw: raw, conversationId: conversationId, draftContext: draftContext, createIntentText: parsed.argumentText)
        case "cancel":
            return handleCancel(raw: raw, conversationId: conversationId, draftContext: draftContext)
        case "outline":
            return handleOutline(parsed: parsed, raw: raw, conversationId: conversationId, articleContext: articleContext)
        case "body":
            return handleBody(parsed: parsed, raw: raw, conversationId: conversationId, articleContext: articleContext)
        default:
            return errorEnvelope(
                code: "CMD-014-EXECUTION_FAILED",
                category: .execution,
                message: "Command is parsed but not enabled in this build.",
                hint: "Try /article help",
                raw: raw,
                namespace: "article",
                verb: parsed.verb,
                subverb: parsed.subverb,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }
    }

    private func requireArticleContext(
        raw: String,
        verb: String,
        subverb: String?,
        conversationId: UUID,
        articleContext: ArticleContext?
    ) -> CommandExecutionEnvelope? {
        guard let articleContext else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "No article selected. Open an article before using this command.",
                hint: "Open an article and retry",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: subverb,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }
        guard articleContext.hasSelection,
              let articleId = articleContext.articleId,
              let articleTitle = articleContext.articleTitle else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "Current article context is unavailable. Reopen the article and retry.",
                hint: "Open the target article and retry",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: subverb,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }
        _ = articleId
        _ = articleTitle
        return nil
    }

    private func handleOutline(
        parsed: ParsedArticleCommand,
        raw: String,
        conversationId: UUID,
        articleContext: ArticleContext?
    ) -> CommandExecutionEnvelope {
        if let stateError = requireArticleContext(
            raw: raw, verb: "outline", subverb: parsed.subverb, conversationId: conversationId, articleContext: articleContext
        ) { return stateError }

        let articleId = articleContext!.articleId!
        let articleTitle = articleContext!.articleTitle!

        let commandWithoutSlash = String(raw.dropFirst())
        let tail = String(commandWithoutSlash.dropFirst("article".count))
        let tokens: [String]
        switch tokenize(tail) {
        case .success(let t): tokens = t
        case .failure(let e): return e
        }

        // tokens[0] = "outline", tokens[1] = subverb ("append" or "replace")
        guard tokens.count >= 2 else {
            return errorEnvelope(
                code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                message: "Missing outline operation.", hint: "Usage: /article outline <append|replace> ...",
                raw: raw, namespace: "article", verb: "outline", subverb: nil,
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let subverb = tokens[1].lowercased()

        switch subverb {
        case "append":
            guard tokens.count >= 3 else {
                return errorEnvelope(
                    code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                    message: "Missing value for outline append.", hint: "Usage: /article outline append <value>",
                    raw: raw, namespace: "article", verb: "outline", subverb: "append",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[2...].joined(separator: " ")
            return successEnvelope(
                raw: raw, verb: "outline", subverb: "append",
                summary: "Outline item appended to '\(articleTitle)'.",
                nextSuggestedCommand: "/article outline append <more items>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                outlineOperation: CommandEnvelopeOutlineOperation(operation: "append", index: nil, value: value)
            )

        case "replace":
            // Parser enforces: tokens.count >= 4, valid index, last == "--confirm"
            guard tokens.count >= 4,
                  let index = Int(tokens[2]), index >= 1 else {
                return errorEnvelope(
                    code: "CMD-007-INVALID_INDEX", category: .validation,
                    message: "Index must be a 1-based positive integer.",
                    hint: "Usage: /article outline replace <index> <value> --confirm",
                    raw: raw, namespace: "article", verb: "outline", subverb: "replace",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            // Value is everything between the index token and --confirm
            let valueTokens = Array(tokens[3..<(tokens.count - 1)])
            let value = valueTokens.joined(separator: " ")
            guard !value.isEmpty else {
                return errorEnvelope(
                    code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                    message: "Missing replacement value.", hint: "Usage: /article outline replace \(index) <value> --confirm",
                    raw: raw, namespace: "article", verb: "outline", subverb: "replace",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            return successEnvelope(
                raw: raw, verb: "outline", subverb: "replace",
                summary: "Outline line \(index) replaced in '\(articleTitle)'.",
                nextSuggestedCommand: "/article outline append <next item>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                outlineOperation: CommandEnvelopeOutlineOperation(operation: "replace", index: index, value: value)
            )

        default:
            return errorEnvelope(
                code: "CMD-004-UNKNOWN_VERB", category: .parse,
                message: "Unknown outline command '\(subverb)'.", hint: "Try /article help",
                raw: raw, namespace: "article", verb: "outline", subverb: subverb,
                requestId: conversationId.uuidString
            )
        }
    }

    private func handleBody(
        parsed: ParsedArticleCommand,
        raw: String,
        conversationId: UUID,
        articleContext: ArticleContext?
    ) -> CommandExecutionEnvelope {
        if let stateError = requireArticleContext(
            raw: raw, verb: "body", subverb: parsed.subverb, conversationId: conversationId, articleContext: articleContext
        ) { return stateError }

        let articleId = articleContext!.articleId!
        let articleTitle = articleContext!.articleTitle!

        let commandWithoutSlash = String(raw.dropFirst())
        let tail = String(commandWithoutSlash.dropFirst("article".count))
        let tokens: [String]
        switch tokenize(tail) {
        case .success(let t): tokens = t
        case .failure(let e): return e
        }

        guard tokens.count >= 2 else {
            return errorEnvelope(
                code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                message: "Missing body operation.", hint: "Usage: /article body <append|insert> ...",
                raw: raw, namespace: "article", verb: "body", subverb: nil,
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let subverb = tokens[1].lowercased()

        switch subverb {
        case "append":
            guard tokens.count >= 3 else {
                return errorEnvelope(
                    code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                    message: "Missing value for body append.", hint: "Usage: /article body append <value>",
                    raw: raw, namespace: "article", verb: "body", subverb: "append",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[2...].joined(separator: " ")
            return successEnvelope(
                raw: raw, verb: "body", subverb: "append",
                summary: "Paragraph appended to body of '\(articleTitle)'.",
                nextSuggestedCommand: "/article body append <more content>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                bodyOperation: CommandEnvelopeBodyOperation(operation: "append", blockType: nil, index: nil, value: value)
            )

        case "insert":
            // tokens: ["body", "insert", blockType, index, value...]
            guard tokens.count >= 5 else {
                return errorEnvelope(
                    code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                    message: "Missing body insert arguments.",
                    hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                    raw: raw, namespace: "article", verb: "body", subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let blockType = tokens[2].lowercased()
            guard ["heading", "paragraph"].contains(blockType) else {
                return errorEnvelope(
                    code: "CMD-005-MISSING_ARGUMENT", category: .validation,
                    message: "Block type must be heading or paragraph.",
                    hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                    raw: raw, namespace: "article", verb: "body", subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            guard let index = Int(tokens[3]), index >= 1 else {
                return errorEnvelope(
                    code: "CMD-007-INVALID_INDEX", category: .validation,
                    message: "Index must be a 1-based positive integer.",
                    hint: "Use a 1-based positive index",
                    raw: raw, namespace: "article", verb: "body", subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[4...].joined(separator: " ")
            return successEnvelope(
                raw: raw, verb: "body", subverb: "insert",
                summary: "\(blockType.capitalized) inserted at position \(index) in '\(articleTitle)'.",
                nextSuggestedCommand: "/article body append <more content>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                bodyOperation: CommandEnvelopeBodyOperation(operation: "insert", blockType: blockType, index: index, value: value)
            )

        default:
            return errorEnvelope(
                code: "CMD-004-UNKNOWN_VERB", category: .parse,
                message: "Unknown body command '\(subverb)'.", hint: "Try /article help",
                raw: raw, namespace: "article", verb: "body", subverb: subverb,
                requestId: conversationId.uuidString
            )
        }
    }

    private func handleNew(
        raw: String,
        conversationId: UUID,
        draftContext: DraftContext?
    ) -> CommandExecutionEnvelope {
        // /article new always succeeds; creates/resets draft session
        return successEnvelope(
            raw: raw,
            verb: "new",
            subverb: nil,
            summary: "New article draft started. Share a short summary of what you want to write, and I will prefill the new article form.",
            nextSuggestedCommand: "Reply with a 1-3 sentence article summary",
            target: CommandEnvelopeTarget(
                articleId: nil,
                articleTitle: nil,
                scope: "draft"
            ),
            draftAction: "start"
        )
    }

    private func handleSet(
        raw: String,
        verb: String,
        conversationId: UUID,
        draftContext: DraftContext?,
        articleContext: ArticleContext?
    ) -> CommandExecutionEnvelope {
        let commandWithoutSlash = String(raw.dropFirst())
        let tail = String(commandWithoutSlash.dropFirst("article".count))
        let tokens: [String]
        switch tokenize(tail) {
        case .success(let parsedTokens):
            tokens = parsedTokens
        case .failure(let envelope):
            return envelope
        }

        guard tokens.count >= 3 else {
            return errorEnvelope(
                code: "CMD-005-MISSING_ARGUMENT",
                category: .validation,
                message: "Missing field or value.",
                hint: "Usage: /article set <field> <value>",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }

        let field = tokens[1]
        let value = tokens[2]

        guard Self.supportedFields.contains(field.lowercased()) else {
            return errorEnvelope(
                code: "CMD-008-UNKNOWN_FIELD",
                category: .validation,
                message: "Unknown field '\(field)'.",
                hint: "Use /article help for valid fields",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }

        if let draftContext, draftContext.isActive {
            return successEnvelope(
                raw: raw,
                verb: verb,
                subverb: nil,
                summary: "Field '\(field)' set to '\(value)'.",
                nextSuggestedCommand: Self.nextStepAfterDraftSet(field: field),
                target: CommandEnvelopeTarget(
                    articleId: nil,
                    articleTitle: nil,
                    scope: "draft"
                ),
                draftAction: "set:\(field)=\(value)"
            )
        }

        guard let articleContext else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "No active draft or article context. Start with /article new or open an article.",
                hint: "/article new or open an article",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        guard articleContext.hasSelection else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "No active draft or article context. Start with /article new or open an article.",
                hint: "/article new or open an article",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        guard let articleId = articleContext.articleId,
              let articleTitle = articleContext.articleTitle else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "Current article context is unavailable. Reopen the article and retry.",
                hint: "Open the target article and retry",
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        switch ArticleContextMutationAdapter().validate(field: field, value: value) {
        case .failure(let error):
            return errorEnvelope(
                code: error.code,
                category: .validation,
                message: error.message,
                hint: error.hint,
                raw: raw,
                namespace: "article",
                verb: verb,
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                requestId: conversationId.uuidString
            )
        case .success(let request):
            return successEnvelope(
                raw: raw,
                verb: verb,
                subverb: nil,
                summary: "Field '\(request.field)' updated on article '\(articleTitle)'.",
                nextSuggestedCommand: "/article update <field> <value>",
                target: CommandEnvelopeTarget(
                    articleId: articleId,
                    articleTitle: articleTitle,
                    scope: "article"
                ),
                articleMutation: CommandEnvelopeArticleMutation(field: request.field, value: request.value)
            )
        }
    }

    private func handleCreate(
        raw: String,
        conversationId: UUID,
        draftContext: DraftContext?,
        createIntentText: String?
    ) -> CommandExecutionEnvelope {
        guard let draftContext = draftContext, draftContext.isActive else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "No active draft session. Start one with /article new.",
                hint: "/article new",
                raw: raw,
                namespace: "article",
                verb: "create",
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }

        let inferredTitle = createIntentText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInferredTitle = inferredTitle?.isEmpty == false ? inferredTitle : nil
        let draftTitle = draftContext.draftFields["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDraftTitle = draftTitle?.isEmpty == false ? draftTitle : nil
        let resolvedTitle = normalizedDraftTitle ?? normalizedInferredTitle

        // Validate required fields
        guard let titleValue = resolvedTitle else {
            return errorEnvelope(
                code: "CMD-011-VALIDATION_FAILED",
                category: .validation,
                message: "Cannot create article: title is required.",
                hint: "/article set title \"Your Title\" or /article create <title/topic>",
                raw: raw,
                namespace: "article",
                verb: "create",
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }

        let draftAction: String
        if normalizedDraftTitle == nil, let inferred = normalizedInferredTitle {
            draftAction = "create:title=\(inferred)"
        } else {
            draftAction = "create"
        }

        // Article creation succeeds; AppState will persist it
        return successEnvelope(
            raw: raw,
            verb: "create",
            subverb: nil,
            summary: "Article '\(titleValue)' created successfully.",
            nextSuggestedCommand: "/article outline append \"<first outline item>\"",
            target: CommandEnvelopeTarget(
                articleId: nil,
                articleTitle: titleValue,
                scope: "article"
            ),
            draftAction: draftAction
        )
    }

    private func handleCancel(
        raw: String,
        conversationId: UUID,
        draftContext: DraftContext?
    ) -> CommandExecutionEnvelope {
        guard let draftContext = draftContext, draftContext.isActive else {
            return errorEnvelope(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "No active draft session to cancel.",
                hint: "/article new",
                raw: raw,
                namespace: "article",
                verb: "cancel",
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                requestId: conversationId.uuidString
            )
        }

        return successEnvelope(
            raw: raw,
            verb: "cancel",
            subverb: nil,
            summary: "Draft session cancelled.",
            nextSuggestedCommand: "/article new",
            target: CommandEnvelopeTarget(
                articleId: nil,
                articleTitle: nil,
                scope: "draft"
            ),
            draftAction: "cancel"
        )
    }

    private func tokenize(_ text: String) -> Result<[String], CommandExecutionEnvelope> {
        let characters = Array(text)
        var tokens: [String] = []
        var index = 0

        func skipWhitespace() {
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
        }

        while index < characters.count {
            skipWhitespace()
            if index >= characters.count { break }

            if characters[index] == "\"" {
                index += 1
                var token = ""
                var terminated = false

                while index < characters.count {
                    let char = characters[index]
                    if char == "\\" {
                        index += 1
                        guard index < characters.count else { break }
                        switch characters[index] {
                        case "\"": token.append("\"")
                        case "\\": token.append("\\")
                        case "n": token.append("\n")
                        case "t": token.append("\t")
                        default: token.append(characters[index])
                        }
                        index += 1
                        continue
                    }

                    if char == "\"" {
                        terminated = true
                        index += 1
                        break
                    }

                    token.append(char)
                    index += 1
                }

                guard terminated else {
                    return .failure(errorEnvelope(
                        code: "CMD-006-UNTERMINATED_QUOTE",
                        category: .parse,
                        message: "Unterminated quoted value.",
                        hint: "Close the quote and retry",
                        raw: "/article \(text.trimmingCharacters(in: .whitespacesAndNewlines))",
                        namespace: "article",
                        verb: nil,
                        subverb: nil
                    ))
                }

                tokens.append(token)
            } else {
                var token = ""
                while index < characters.count, !characters[index].isWhitespace {
                    token.append(characters[index])
                    index += 1
                }
                tokens.append(token)
            }
        }

        return .success(tokens)
    }

    private func successEnvelope(
        raw: String,
        verb: String,
        subverb: String?,
        summary: String,
        nextSuggestedCommand: String?,
        target: CommandEnvelopeTarget?,
        draftAction: String? = nil,
        articleMutation: CommandEnvelopeArticleMutation? = nil,
        outlineOperation: CommandEnvelopeOutlineOperation? = nil,
        bodyOperation: CommandEnvelopeBodyOperation? = nil
    ) -> CommandExecutionEnvelope {
        CommandExecutionEnvelope(
            ok: true,
            requestId: UUID().uuidString,
            timestamp: isoFormatter.string(from: Date()),
            command: CommandEnvelopeCommand(
                namespace: "article",
                verb: verb,
                subverb: subverb,
                raw: raw
            ),
            target: target,
            result: CommandEnvelopeResult(
                summary: summary,
                nextSuggestedCommand: nextSuggestedCommand
            ),
            error: nil,
            draftAction: draftAction,
            articleMutation: articleMutation,
            outlineOperation: outlineOperation,
            bodyOperation: bodyOperation
        )
    }

    private func errorEnvelope(
        code: String,
        category: CommandErrorCategory,
        message: String,
        hint: String,
        raw: String,
        namespace: String,
        verb: String?,
        subverb: String?,
        target: CommandEnvelopeTarget? = nil,
        requestId: String? = nil,
        draftAction: String? = nil,
        articleMutation: CommandEnvelopeArticleMutation? = nil,
        outlineOperation: CommandEnvelopeOutlineOperation? = nil,
        bodyOperation: CommandEnvelopeBodyOperation? = nil
    ) -> CommandExecutionEnvelope {
        CommandExecutionEnvelope(
            ok: false,
            requestId: requestId ?? UUID().uuidString,
            timestamp: isoFormatter.string(from: Date()),
            command: CommandEnvelopeCommand(
                namespace: namespace,
                verb: verb,
                subverb: subverb,
                raw: raw
            ),
            target: target,
            result: nil,
            error: CommandEnvelopeError(
                code: code,
                category: category,
                message: message,
                recoverable: true,
                hint: hint
            ),
            draftAction: draftAction,
            articleMutation: articleMutation,
            outlineOperation: outlineOperation,
            bodyOperation: bodyOperation
        )
    }

        // MARK: - Help & feedback copy

        private static let helpSummary: String = """
                Article command reference:

                    /article new
                        Start a new article draft. Resets any in-progress draft.

                    /article set <field> "<value>"
                        Set a draft field before creating an article.
                        Fields: title, subtitle, topic, audience, summary, outline,
                                        purpose, style, tone, length, quicknotes, sourcelinks,
                                        keytakeaway, publishingintent, targetlength
                        Example: /article set title "My Article Title"

                    /article create
                        Persist the current draft as a new article. Requires title.

                    /article cancel
                        Discard the current draft without creating an article.

                    /article update <field> "<value>"
                        Update a field on the currently open article (post-create).
                        Same field set as /article set.

                    /article outline append "<item>"
                        Append a line to the article outline.
                        Example: /article outline append "Introduction"

                    /article outline replace <n> "<value>" --confirm
                        Replace outline line n (1-based index). --confirm is required.
                        Example: /article outline replace 2 "Revised Section" --confirm

                    /article body append "<text>"
                        Append a paragraph to the article body.
                        Example: /article body append "Opening paragraph text."

                    /article body insert <heading|paragraph> <n> "<text>"
                        Insert a block at 1-based body position n.
                        Example: /article body insert heading 1 "Introduction"

                Start with: /article new
                """

        private static func nextStepAfterDraftSet(field: String) -> String {
                switch field.lowercased() {
                case "title":
                        return "/article set topic \"<your topic>\""
                case "topic":
                        return "/article set audience \"<your audience>\""
                case "audience":
                        return "/article set summary \"<brief summary>\""
                case "summary":
                        return "/article create"
                default:
                        return "/article create"
                }
        }

    private static let supportedFields: Set<String> = [
        "title",
        "subtitle",
        "topic",
        "audience",
        "quicknotes",
        "sourcelinks",
        "outline",
        "summary",
        "purpose",
        "style",
        "keytakeaway",
        "publishingintent",
        "tone",
        "length",
        "targetlength"
    ]
}