//
//  CommandRouter.swift
//  WriteVibe
//

import Foundation

struct ParsedCommandRoute {
    let raw: String
    let namespace: String
    let tail: String
}

enum CommandRoutingResult {
    case notACommand
    case handled(CommandExecutionEnvelope)
    case routed(ParsedCommandRoute)
}

@MainActor
final class CommandRouter {
    private let envelopeFactory: CommandEnvelopeFactory

    init(envelopeFactory: CommandEnvelopeFactory) {
        self.envelopeFactory = envelopeFactory
    }

    func route(input rawInput: String) -> CommandRoutingResult {
        let raw = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return .handled(envelopeFactory.error(
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
        let namespace = commandWithoutSlash
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .lowercased() ?? ""

        if ["script", "scripts", "email", "emails"].contains(namespace) {
            return .handled(envelopeFactory.error(
                code: "CMD-013-DOMAIN_BOUNDARY_REJECTED",
                category: .domain,
                message: "This app only supports article and series commands.",
                hint: "Use /article help or /series help",
                raw: raw,
                namespace: namespace.isEmpty ? "unknown" : namespace,
                verb: nil,
                subverb: nil
            ))
        }

        guard ["article", "series"].contains(namespace) else {
            return .handled(envelopeFactory.error(
                code: "CMD-003-UNKNOWN_NAMESPACE",
                category: .domain,
                message: "Only /article and /series commands are supported in this app.",
                hint: "Use /article help or /series help",
                raw: raw,
                namespace: namespace.isEmpty ? "unknown" : namespace,
                verb: nil,
                subverb: nil
            ))
        }

        let tail = String(commandWithoutSlash.dropFirst(namespace.count))
        return .routed(ParsedCommandRoute(raw: raw, namespace: namespace, tail: tail))
    }
}
