//
//  SeriesCommandService.swift
//  WriteVibe
//

import Foundation
import SwiftData

private struct ParsedSeriesCommand {
	let verb: String
	let argumentText: String?
}

@MainActor
final class SeriesCommandService {
	private let envelopeFactory: CommandEnvelopeFactory

	init(envelopeFactory: CommandEnvelopeFactory) {
		self.envelopeFactory = envelopeFactory
	}

	func handle(
		route: ParsedCommandRoute,
		conversationId: UUID,
		context: ModelContext,
		seriesContext: CommandExecutionService.SeriesContext?
	) -> CommandExecutionEnvelope {
		switch parseSeriesCommand(route.tail) {
		case .failure(let envelope):
			return envelope
		case .success(let parsed):
			switch parsed.verb {
			case "help":
				return envelopeFactory.success(
					namespace: "series",
					raw: route.raw,
					verb: "help",
					subverb: nil,
					summary: Self.helpSummary,
					nextSuggestedCommand: "/series list",
					target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "series")
				)
			case "list":
				return envelopeFactory.success(
					namespace: "series",
					raw: route.raw,
					verb: "list",
					subverb: nil,
					summary: "Series dashboard opened.",
					nextSuggestedCommand: "/series open \"<series title>\"",
					target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "series"),
					mutation: CommandMutationEnvelope(
						domain: .series,
						payload: .series(.focusDashboard)
					)
				)
			case "open":
				return handleOpen(
					route: route,
					conversationId: conversationId,
					context: context,
					seriesContext: seriesContext,
					argumentText: parsed.argumentText
				)
			default:
				return envelopeFactory.error(
					code: "CMD-014-EXECUTION_FAILED",
					category: .execution,
					message: "Series command is parsed but not enabled in this build.",
					hint: "Try /series help",
					raw: route.raw,
					namespace: "series",
					verb: parsed.verb,
					subverb: nil,
					target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "series"),
					requestId: conversationId.uuidString
				)
			}
		}
	}

	private func parseSeriesCommand(_ tail: String) -> Result<ParsedSeriesCommand, CommandExecutionEnvelope> {
		switch tokenize(tail) {
		case .failure(let error):
			return .failure(error)
		case .success(let tokens):
			guard let verb = tokens.first?.lowercased() else {
				return .failure(envelopeFactory.error(
					code: "CMD-004-UNKNOWN_VERB",
					category: .parse,
					message: "Unknown series command.",
					hint: "Try /series help",
					raw: "/series",
					namespace: "series",
					verb: nil,
					subverb: nil
				))
			}

			switch verb {
			case "help", "list":
				guard tokens.count == 1 else {
					return .failure(envelopeFactory.error(
						code: "CMD-005-MISSING_ARGUMENT",
						category: .validation,
						message: "Unexpected arguments for /series \(verb).",
						hint: "Usage: /series \(verb)",
						raw: "/series \(tokens.joined(separator: " "))",
						namespace: "series",
						verb: verb,
						subverb: nil
					))
				}
				return .success(ParsedSeriesCommand(verb: verb, argumentText: nil))

			case "open":
				let argument: String?
				if tokens.count > 1 {
					let text = tokens.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
					argument = text.isEmpty ? nil : text
				} else {
					argument = nil
				}
				return .success(ParsedSeriesCommand(verb: "open", argumentText: argument))

			default:
				return .failure(envelopeFactory.error(
					code: "CMD-004-UNKNOWN_VERB",
					category: .parse,
					message: "Unknown series command.",
					hint: "Try /series help",
					raw: "/series \(tokens.joined(separator: " "))",
					namespace: "series",
					verb: verb,
					subverb: nil
				))
			}
		}
	}

	private func handleOpen(
		route: ParsedCommandRoute,
		conversationId: UUID,
		context: ModelContext,
		seriesContext: CommandExecutionService.SeriesContext?,
		argumentText: String?
	) -> CommandExecutionEnvelope {
		let resolved: (id: String, title: String)?

		if let argument = argumentText {
			resolved = resolveSeries(argument: argument, context: context)
		} else if let seriesContext,
				  seriesContext.hasSeriesContext,
				  let seriesId = seriesContext.seriesId,
				  let seriesTitle = seriesContext.seriesTitle {
			resolved = (seriesId, seriesTitle)
		} else {
			resolved = nil
		}

		guard let resolved else {
			return envelopeFactory.error(
				code: "CMD-011-VALIDATION_FAILED",
				category: .validation,
				message: "No matching series found.",
				hint: "Use /series list, then /series open \"<series title>\"",
				raw: route.raw,
				namespace: "series",
				verb: "open",
				subverb: nil,
				target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "series"),
				requestId: conversationId.uuidString
			)
		}

		return envelopeFactory.success(
			namespace: "series",
			raw: route.raw,
			verb: "open",
			subverb: nil,
			summary: "Series '\(resolved.title)' opened.",
			nextSuggestedCommand: "/series list",
			target: CommandEnvelopeTarget(articleId: nil, articleTitle: nil, scope: "series"),
			mutation: CommandMutationEnvelope(
				domain: .series,
				payload: .series(.selectSeries(CommandEnvelopeSeriesSelection(seriesId: resolved.id, seriesTitle: resolved.title)))
			)
		)
	}

	private func resolveSeries(argument: String, context: ModelContext) -> (id: String, title: String)? {
		let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }

		if let uuid = UUID(uuidString: trimmed) {
			let descriptor = FetchDescriptor<Series>(predicate: #Predicate<Series> { series in
				series.id == uuid
			})
			if let match = try? context.fetch(descriptor).first {
				return (match.id.uuidString, match.title)
			}
		}

		let descriptor = FetchDescriptor<Series>()
		guard let allSeries = try? context.fetch(descriptor) else { return nil }
		guard let match = allSeries.first(where: { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
			return nil
		}
		return (match.id.uuidString, match.title)
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
						raw: "/series \(text.trimmingCharacters(in: .whitespacesAndNewlines))",
						namespace: "series",
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
			Series command reference:

				/series help
					Show series command usage.

				/series list
					Focus the Series dashboard.

				/series open \"<series title>\"
					Open a specific series workspace by title.
					You can also pass a series UUID.

			Start with: /series list
			"""
}