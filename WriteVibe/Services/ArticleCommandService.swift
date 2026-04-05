//
//  ArticleCommandService.swift
//  WriteVibe
//

import Foundation

private struct ParsedArticleCommand {
    let verb: String
    let subverb: String?
    let argumentText: String?
}

@MainActor
final class ArticleCommandService {
    private let envelopeFactory: CommandEnvelopeFactory

    init(envelopeFactory: CommandEnvelopeFactory) {
        self.envelopeFactory = envelopeFactory
    }

    func handle(
        route: ParsedCommandRoute,
        conversationId: UUID,
        draftContext: CommandExecutionService.DraftContext?,
        articleContext: CommandExecutionService.ArticleContext?
    ) -> CommandExecutionEnvelope {
        switch parseArticleCommand(route.tail) {
        case .failure(let envelope):
            return envelope
        case .success(let parsed):
            return dispatchArticle(
                parsed,
                raw: route.raw,
                conversationId: conversationId,
                draftContext: draftContext,
                articleContext: articleContext
            )
        }
    }

    private func parseArticleCommand(_ tail: String) -> Result<ParsedArticleCommand, CommandExecutionEnvelope> {
        switch tokenize(tail) {
        case .failure(let error):
            return .failure(error)
        case .success(let tokens):
            guard let verb = tokens.first?.lowercased() else {
                return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                        return .failure(envelopeFactory.error(
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
                    return .failure(envelopeFactory.error(
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
                return .failure(envelopeFactory.error(
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
        draftContext: CommandExecutionService.DraftContext?,
        articleContext: CommandExecutionService.ArticleContext?
    ) -> CommandExecutionEnvelope {
        if parsed.verb == "help" {
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: parsed.verb,
                subverb: parsed.subverb,
                summary: Self.helpSummary,
                nextSuggestedCommand: "/article new",
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "help")
            )
        }

        switch parsed.verb {
        case "new":
            return handleNew(raw: raw)
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
            return envelopeFactory.error(
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
        articleContext: CommandExecutionService.ArticleContext?
    ) -> CommandExecutionEnvelope? {
        guard let articleContext else {
            return envelopeFactory.error(
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
        guard articleContext.hasArticleContext,
              articleContext.articleId != nil,
              articleContext.articleTitle != nil else {
            return envelopeFactory.error(
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
        return nil
    }

    private func handleOutline(
        parsed: ParsedArticleCommand,
        raw: String,
        conversationId: UUID,
        articleContext: CommandExecutionService.ArticleContext?
    ) -> CommandExecutionEnvelope {
        if let stateError = requireArticleContext(raw: raw, verb: "outline", subverb: parsed.subverb, conversationId: conversationId, articleContext: articleContext) {
            return stateError
        }

        guard let articleId = articleContext?.articleId,
              let articleTitle = articleContext?.articleTitle else {
            return envelopeFactory.error(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "Current article context is unavailable. Reopen the article and retry.",
                hint: "Open the target article and retry",
                raw: raw,
                namespace: "article",
                verb: "outline",
                subverb: parsed.subverb,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let commandWithoutSlash = String(raw.dropFirst())
        let tail = String(commandWithoutSlash.dropFirst("article".count))
        let tokens: [String]
        switch tokenize(tail) {
        case .success(let t): tokens = t
        case .failure(let e): return e
        }

        guard tokens.count >= 2 else {
            return envelopeFactory.error(
                code: "CMD-005-MISSING_ARGUMENT",
                category: .validation,
                message: "Missing outline operation.",
                hint: "Usage: /article outline <append|replace> ...",
                raw: raw,
                namespace: "article",
                verb: "outline",
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let subverb = tokens[1].lowercased()
        switch subverb {
        case "append":
            guard tokens.count >= 3 else {
                return envelopeFactory.error(
                    code: "CMD-005-MISSING_ARGUMENT",
                    category: .validation,
                    message: "Missing value for outline append.",
                    hint: "Usage: /article outline append <value>",
                    raw: raw,
                    namespace: "article",
                    verb: "outline",
                    subverb: "append",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[2...].joined(separator: " ")
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: "outline",
                subverb: "append",
                summary: "Outline item appended to '\(articleTitle)'.",
                nextSuggestedCommand: "/article outline append <more items>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                mutation: CommandMutationEnvelope(
                    domain: .article,
                    payload: .articleOutline(CommandEnvelopeOutlineOperation(operation: "append", index: nil, value: value))
                )
            )

        case "replace":
            guard tokens.count >= 4, let index = Int(tokens[2]), index >= 1 else {
                return envelopeFactory.error(
                    code: "CMD-007-INVALID_INDEX",
                    category: .validation,
                    message: "Index must be a 1-based positive integer.",
                    hint: "Usage: /article outline replace <index> <value> --confirm",
                    raw: raw,
                    namespace: "article",
                    verb: "outline",
                    subverb: "replace",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let valueTokens = Array(tokens[3..<(tokens.count - 1)])
            let value = valueTokens.joined(separator: " ")
            guard !value.isEmpty else {
                return envelopeFactory.error(
                    code: "CMD-005-MISSING_ARGUMENT",
                    category: .validation,
                    message: "Missing replacement value.",
                    hint: "Usage: /article outline replace \(index) <value> --confirm",
                    raw: raw,
                    namespace: "article",
                    verb: "outline",
                    subverb: "replace",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: "outline",
                subverb: "replace",
                summary: "Outline line \(index) replaced in '\(articleTitle)'.",
                nextSuggestedCommand: "/article outline append <next item>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                mutation: CommandMutationEnvelope(
                    domain: .article,
                    payload: .articleOutline(CommandEnvelopeOutlineOperation(operation: "replace", index: index, value: value))
                )
            )

        default:
            return envelopeFactory.error(
                code: "CMD-004-UNKNOWN_VERB",
                category: .parse,
                message: "Unknown outline command '\(subverb)'.",
                hint: "Try /article help",
                raw: raw,
                namespace: "article",
                verb: "outline",
                subverb: subverb,
                requestId: conversationId.uuidString
            )
        }
    }

    private func handleBody(
        parsed: ParsedArticleCommand,
        raw: String,
        conversationId: UUID,
        articleContext: CommandExecutionService.ArticleContext?
    ) -> CommandExecutionEnvelope {
        if let stateError = requireArticleContext(raw: raw, verb: "body", subverb: parsed.subverb, conversationId: conversationId, articleContext: articleContext) {
            return stateError
        }

        guard let articleId = articleContext?.articleId,
              let articleTitle = articleContext?.articleTitle else {
            return envelopeFactory.error(
                code: "CMD-010-STATE_ERROR",
                category: .state,
                message: "Current article context is unavailable. Reopen the article and retry.",
                hint: "Open the target article and retry",
                raw: raw,
                namespace: "article",
                verb: "body",
                subverb: parsed.subverb,
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let commandWithoutSlash = String(raw.dropFirst())
        let tail = String(commandWithoutSlash.dropFirst("article".count))
        let tokens: [String]
        switch tokenize(tail) {
        case .success(let t): tokens = t
        case .failure(let e): return e
        }

        guard tokens.count >= 2 else {
            return envelopeFactory.error(
                code: "CMD-005-MISSING_ARGUMENT",
                category: .validation,
                message: "Missing body operation.",
                hint: "Usage: /article body <append|insert> ...",
                raw: raw,
                namespace: "article",
                verb: "body",
                subverb: nil,
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                requestId: conversationId.uuidString
            )
        }

        let subverb = tokens[1].lowercased()
        switch subverb {
        case "append":
            guard tokens.count >= 3 else {
                return envelopeFactory.error(
                    code: "CMD-005-MISSING_ARGUMENT",
                    category: .validation,
                    message: "Missing value for body append.",
                    hint: "Usage: /article body append <value>",
                    raw: raw,
                    namespace: "article",
                    verb: "body",
                    subverb: "append",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[2...].joined(separator: " ")
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: "body",
                subverb: "append",
                summary: "Paragraph appended to body of '\(articleTitle)'.",
                nextSuggestedCommand: "/article body append <more content>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                mutation: CommandMutationEnvelope(
                    domain: .article,
                    payload: .articleBody(CommandEnvelopeBodyOperation(operation: "append", blockType: nil, index: nil, value: value))
                )
            )

        case "insert":
            guard tokens.count >= 5 else {
                return envelopeFactory.error(
                    code: "CMD-005-MISSING_ARGUMENT",
                    category: .validation,
                    message: "Missing body insert arguments.",
                    hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                    raw: raw,
                    namespace: "article",
                    verb: "body",
                    subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let blockType = tokens[2].lowercased()
            guard ["heading", "paragraph"].contains(blockType) else {
                return envelopeFactory.error(
                    code: "CMD-005-MISSING_ARGUMENT",
                    category: .validation,
                    message: "Block type must be heading or paragraph.",
                    hint: "Usage: /article body insert <heading|paragraph> <index> <value>",
                    raw: raw,
                    namespace: "article",
                    verb: "body",
                    subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            guard let index = Int(tokens[3]), index >= 1 else {
                return envelopeFactory.error(
                    code: "CMD-007-INVALID_INDEX",
                    category: .validation,
                    message: "Index must be a 1-based positive integer.",
                    hint: "Use a 1-based positive index",
                    raw: raw,
                    namespace: "article",
                    verb: "body",
                    subverb: "insert",
                    target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                    requestId: conversationId.uuidString
                )
            }
            let value = tokens[4...].joined(separator: " ")
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: "body",
                subverb: "insert",
                summary: "\(blockType.capitalized) inserted at position \(index) in '\(articleTitle)'.",
                nextSuggestedCommand: "/article body append <more content>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                mutation: CommandMutationEnvelope(
                    domain: .article,
                    payload: .articleBody(CommandEnvelopeBodyOperation(operation: "insert", blockType: blockType, index: index, value: value))
                )
            )

        default:
            return envelopeFactory.error(
                code: "CMD-004-UNKNOWN_VERB",
                category: .parse,
                message: "Unknown body command '\(subverb)'.",
                hint: "Try /article help",
                raw: raw,
                namespace: "article",
                verb: "body",
                subverb: subverb,
                requestId: conversationId.uuidString
            )
        }
    }

    private func handleNew(raw: String) -> CommandExecutionEnvelope {
        envelopeFactory.success(
            namespace: "article",
            raw: raw,
            verb: "new",
            subverb: nil,
            summary: "New article draft started. Share a short summary of what you want to write, and I will prefill the new article form.",
            nextSuggestedCommand: "Reply with a 1-3 sentence article summary",
            target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
            draftAction: "start"
        )
    }

    private func handleSet(
        raw: String,
        verb: String,
        conversationId: UUID,
        draftContext: CommandExecutionService.DraftContext?,
        articleContext: CommandExecutionService.ArticleContext?
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
            return envelopeFactory.error(
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
            return envelopeFactory.error(
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
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: verb,
                subverb: nil,
                summary: "Field '\(field)' set to '\(value)'.",
                nextSuggestedCommand: Self.nextStepAfterDraftSet(field: field),
                target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
                draftAction: "set:\(field)=\(value)"
            )
        }

        guard let articleContext, articleContext.hasArticleContext else {
            return envelopeFactory.error(
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
            return envelopeFactory.error(
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
            return envelopeFactory.error(
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
            return envelopeFactory.success(
                namespace: "article",
                raw: raw,
                verb: verb,
                subverb: nil,
                summary: "Field '\(request.field)' updated on article '\(articleTitle)'.",
                nextSuggestedCommand: "/article update <field> <value>",
                target: CommandEnvelopeTarget(articleId: articleId, articleTitle: articleTitle, scope: "article"),
                mutation: CommandMutationEnvelope(
                    domain: .article,
                    payload: .articleContext(CommandEnvelopeArticleMutation(field: request.field, value: request.value))
                )
            )
        }
    }

    private func handleCreate(
        raw: String,
        conversationId: UUID,
        draftContext: CommandExecutionService.DraftContext?,
        createIntentText: String?
    ) -> CommandExecutionEnvelope {
        guard let draftContext = draftContext, draftContext.isActive else {
            return envelopeFactory.error(
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

        guard let titleValue = resolvedTitle else {
            return envelopeFactory.error(
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

        return envelopeFactory.success(
            namespace: "article",
            raw: raw,
            verb: "create",
            subverb: nil,
            summary: "Article '\(titleValue)' created successfully.",
            nextSuggestedCommand: "/article outline append \"<first outline item>\"",
            target: CommandEnvelopeTarget(articleId: nil, articleTitle: titleValue, scope: "article"),
            draftAction: draftAction
        )
    }

    private func handleCancel(
        raw: String,
        conversationId: UUID,
        draftContext: CommandExecutionService.DraftContext?
    ) -> CommandExecutionEnvelope {
        guard let draftContext = draftContext, draftContext.isActive else {
            return envelopeFactory.error(
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

        return envelopeFactory.success(
            namespace: "article",
            raw: raw,
            verb: "cancel",
            subverb: nil,
            summary: "Draft session cancelled.",
            nextSuggestedCommand: "/article new",
            target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "draft"),
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
                    return .failure(envelopeFactory.error(
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

    private static let helpSummary: String = """
            Article command reference:

                /article new
                    Start a new article draft. Resets any in-progress draft.

                /article set <field> \"<value>\"
                    Set a draft field before creating an article.
                    Fields: title, subtitle, topic, audience, summary, outline,
                                    purpose, style, tone, length, quicknotes, sourcelinks,
                                    keytakeaway, publishingintent, targetlength
                    Example: /article set title \"My Article Title\"

                /article create
                    Persist the current draft as a new article. Requires title.

                /article cancel
                    Discard the current draft without creating an article.

                /article update <field> \"<value>\"
                    Update a field on the currently open article (post-create).
                    Same field set as /article set.

                /article outline append \"<item>\"
                    Append a line to the article outline.
                    Example: /article outline append \"Introduction\"

                /article outline replace <n> \"<value>\" --confirm
                    Replace outline line n (1-based index). --confirm is required.
                    Example: /article outline replace 2 \"Revised Section\" --confirm

                /article body append \"<text>\"
                    Append a paragraph to the article body.
                    Example: /article body append \"Opening paragraph text.\"

                /article body insert <heading|paragraph> <n> \"<text>\"
                    Insert a block at 1-based body position n.
                    Example: /article body insert heading 1 \"Introduction\"

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
