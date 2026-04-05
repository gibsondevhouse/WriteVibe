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

struct CommandEnvelopeArticleMutation: Codable, Equatable, Sendable {
    let field: String
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeArticleMutation, rhs: CommandEnvelopeArticleMutation) -> Bool {
        lhs.field == rhs.field
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeOutlineOperation: Codable, Equatable, Sendable {
    let operation: String
    let index: Int?
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeOutlineOperation, rhs: CommandEnvelopeOutlineOperation) -> Bool {
        lhs.operation == rhs.operation
            && lhs.index == rhs.index
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeBodyOperation: Codable, Equatable, Sendable {
    let operation: String
    let blockType: String?
    let index: Int?
    let value: String

    nonisolated static func == (lhs: CommandEnvelopeBodyOperation, rhs: CommandEnvelopeBodyOperation) -> Bool {
        lhs.operation == rhs.operation
            && lhs.blockType == rhs.blockType
            && lhs.index == rhs.index
            && lhs.value == rhs.value
    }
}

struct CommandEnvelopeSeriesSelection: Codable, Equatable, Sendable {
    let seriesId: String
    let seriesTitle: String
}

enum SeriesCommandMutation: Codable, Equatable, Sendable {
    case focusDashboard
    case selectSeries(CommandEnvelopeSeriesSelection)
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

enum CommandMutationDomain: String, Codable, Equatable, Sendable {
    case article
    case series
}

enum CommandMutationPayload: Codable, Equatable, Sendable {
    case articleContext(CommandEnvelopeArticleMutation)
    case articleOutline(CommandEnvelopeOutlineOperation)
    case articleBody(CommandEnvelopeBodyOperation)
    case series(SeriesCommandMutation)
}

struct CommandMutationEnvelope: Codable, Equatable, Sendable {
    let domain: CommandMutationDomain
    let payload: CommandMutationPayload
}

struct CommandResult: Codable, Equatable, Sendable {
    let summary: String
    let nextSuggestedCommand: String?
    let draftAction: String?
    let mutation: CommandMutationEnvelope?
}

struct CommandExecutionEnvelope: Codable, Equatable, Error, Sendable {
    let ok: Bool
    let requestId: String
    let timestamp: String
    let command: CommandEnvelopeCommand
    let target: CommandEnvelopeTarget?
    let result: CommandResult?
    let error: CommandEnvelopeError?

    nonisolated static func == (lhs: CommandExecutionEnvelope, rhs: CommandExecutionEnvelope) -> Bool {
        lhs.ok == rhs.ok
            && lhs.requestId == rhs.requestId
            && lhs.timestamp == rhs.timestamp
            && lhs.command == rhs.command
            && lhs.target == rhs.target
            && lhs.result == rhs.result
            && lhs.error == rhs.error
    }

    var draftAction: String? {
        result?.draftAction
    }

    var mutation: CommandMutationEnvelope? {
        result?.mutation
    }

    var articleMutation: CommandEnvelopeArticleMutation? {
        guard let mutation else { return nil }
        guard case .articleContext(let request) = mutation.payload else { return nil }
        return request
    }

    var outlineOperation: CommandEnvelopeOutlineOperation? {
        guard let mutation else { return nil }
        guard case .articleOutline(let request) = mutation.payload else { return nil }
        return request
    }

    var bodyOperation: CommandEnvelopeBodyOperation? {
        guard let mutation else { return nil }
        guard case .articleBody(let request) = mutation.payload else { return nil }
        return request
    }

    var seriesMutation: SeriesCommandMutation? {
        guard let mutation else { return nil }
        guard case .series(let request) = mutation.payload else { return nil }
        return request
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

@MainActor
final class CommandExecutionService {
    struct DraftContext {
        let isActive: Bool
        let draftFields: [String: String]
    }

    struct ArticleContext {
        let hasArticleContext: Bool
        let articleId: String?
        let articleTitle: String?
    }

    struct SeriesContext {
        let hasSeriesContext: Bool
        let seriesId: String?
        let seriesTitle: String?
    }

    private let commandRouter: CommandRouter
    private let articleCommandService: ArticleCommandService
    private let seriesCommandService: SeriesCommandService

    init(
        commandRouter: CommandRouter? = nil,
        articleCommandService: ArticleCommandService? = nil,
        seriesCommandService: SeriesCommandService? = nil,
        envelopeFactory: CommandEnvelopeFactory? = nil
    ) {
        let envelopeFactory = envelopeFactory ?? CommandEnvelopeFactory()
        self.commandRouter = commandRouter ?? CommandRouter(envelopeFactory: envelopeFactory)
        self.articleCommandService = articleCommandService ?? ArticleCommandService(envelopeFactory: envelopeFactory)
        self.seriesCommandService = seriesCommandService ?? SeriesCommandService(envelopeFactory: envelopeFactory)
    }

    func dispatch(
        input rawInput: String,
        conversationId: UUID,
        context: ModelContext,
        draftContext: DraftContext? = nil,
        articleContext: ArticleContext? = nil,
        seriesContext: SeriesContext? = nil
    ) -> CommandDispatchOutcome {
        switch commandRouter.route(input: rawInput) {
        case .notACommand:
            return .notACommand

        case .handled(let envelope):
            return .handled(envelope)

        case .routed(let route):
            switch route.namespace {
            case "article":
                return .handled(articleCommandService.handle(
                    route: route,
                    conversationId: conversationId,
                    draftContext: draftContext,
                    articleContext: articleContext
                ))

            case "series":
                return .handled(seriesCommandService.handle(
                    route: route,
                    conversationId: conversationId,
                    context: context,
                    seriesContext: seriesContext
                ))

            default:
                return .notACommand
            }
        }
    }
}
