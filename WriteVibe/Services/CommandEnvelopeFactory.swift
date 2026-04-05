//
//  CommandEnvelopeFactory.swift
//  WriteVibe
//

import Foundation

@MainActor
final class CommandEnvelopeFactory {
    private let isoFormatter = ISO8601DateFormatter()

    func success(
        namespace: String,
        raw: String,
        verb: String,
        subverb: String?,
        summary: String,
        nextSuggestedCommand: String?,
        target: CommandEnvelopeTarget?,
        draftAction: String? = nil,
        mutation: CommandMutationEnvelope? = nil,
        requestId: String? = nil
    ) -> CommandExecutionEnvelope {
        CommandExecutionEnvelope(
            ok: true,
            requestId: requestId ?? UUID().uuidString,
            timestamp: isoFormatter.string(from: Date()),
            command: CommandEnvelopeCommand(
                namespace: namespace,
                verb: verb,
                subverb: subverb,
                raw: raw
            ),
            target: target,
            result: CommandResult(
                summary: summary,
                nextSuggestedCommand: nextSuggestedCommand,
                draftAction: draftAction,
                mutation: mutation
            ),
            error: nil
        )
    }

    func error(
        code: String,
        category: CommandErrorCategory,
        message: String,
        hint: String,
        raw: String,
        namespace: String,
        verb: String?,
        subverb: String?,
        target: CommandEnvelopeTarget? = nil,
        requestId: String? = nil
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
            )
        )
    }
}
