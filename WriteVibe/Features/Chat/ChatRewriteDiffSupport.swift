//
//  ChatRewriteDiffSupport.swift
//  WriteVibe
//

import Foundation

enum ChatRewriteAction: String, Equatable {
    case improve
    case rephrase
    case shorten

    var title: String {
        switch self {
        case .improve: return "Improve"
        case .rephrase: return "Rephrase"
        case .shorten: return "Shorten"
        }
    }
}

struct ChatRewriteContext: Equatable {
    let action: ChatRewriteAction
    let sourceText: String
}

struct ChatRewritePreview: Equatable {
    let action: ChatRewriteAction
    let sourceText: String
    let rewrittenText: String
    let spans: [ChangeSpan]
}

enum ChatRewriteDiffSupport {
    static func preview(userPrompt: String, assistantResponse: String) -> ChatRewritePreview? {
        guard let context = context(from: userPrompt) else { return nil }
        let rewrittenText = extractRewriteBody(from: assistantResponse)
        guard !rewrittenText.trimmed.isEmpty else { return nil }

        let spans = DiffEngine.diff(baseline: context.sourceText, current: rewrittenText)
        guard !spans.isEmpty else { return nil }

        return ChatRewritePreview(
            action: context.action,
            sourceText: context.sourceText,
            rewrittenText: rewrittenText,
            spans: spans
        )
    }

    static func context(from userPrompt: String) -> ChatRewriteContext? {
        let trimmedPrompt = userPrompt.trimmed
        guard !trimmedPrompt.isEmpty else { return nil }

        let lines = trimmedPrompt.components(separatedBy: .newlines)
        guard let header = lines.first(where: { !$0.trimmed.isEmpty })?.trimmed,
              let action = action(from: header.lowercased()) else {
            return nil
        }

        let sourceText = extractSourceText(from: trimmedPrompt, header: header).trimmed
        guard !sourceText.isEmpty else { return nil }

        return ChatRewriteContext(action: action, sourceText: sourceText)
    }

    static func extractRewriteBody(from assistantResponse: String) -> String {
        let trimmedResponse = assistantResponse.trimmed
        guard !trimmedResponse.isEmpty else { return "" }

        if let fencedBlock = firstCodeFence(in: trimmedResponse) {
            return fencedBlock.trimmed
        }

        let paragraphs = trimmedResponse
            .components(separatedBy: "\n\n")
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

        guard let firstParagraph = paragraphs.first else { return trimmedResponse }

        let normalizedFirstParagraph = firstParagraph.lowercased()
        if paragraphs.count > 1,
           (normalizedFirstParagraph.hasPrefix("here's")
            || normalizedFirstParagraph.hasPrefix("here is")
            || normalizedFirstParagraph.hasPrefix("rephrased")
            || normalizedFirstParagraph.hasPrefix("shortened")
            || normalizedFirstParagraph.hasPrefix("improved")
            || normalizedFirstParagraph.hasPrefix("rewrite:")) {
            return paragraphs.dropFirst().joined(separator: "\n\n").trimmed
        }

        let lines = trimmedResponse.components(separatedBy: .newlines)
        if let firstLine = lines.first?.trimmed,
           firstLine.hasSuffix(":"),
           lines.count > 1 {
            let remainder = lines.dropFirst().joined(separator: "\n").trimmed
            if !remainder.isEmpty {
                return remainder
            }
        }

        return trimmedResponse
    }

    private static func action(from header: String) -> ChatRewriteAction? {
        if matches(header: header, patterns: [
            "improve this",
            "improve the following",
            "improve this text",
            "improve this paragraph",
            "improve:"
        ]) {
            return .improve
        }

        if matches(header: header, patterns: [
            "rephrase this",
            "rephrase the following",
            "rephrase this text",
            "rephrase this paragraph",
            "rephrase:"
        ]) {
            return .rephrase
        }

        if matches(header: header, patterns: [
            "shorten this",
            "shorten the following",
            "shorten this text",
            "shorten this paragraph",
            "shorten:"
        ]) {
            return .shorten
        }

        return nil
    }

    private static func matches(header: String, patterns: [String]) -> Bool {
        patterns.contains { header.hasPrefix($0) }
    }

    private static func extractSourceText(from prompt: String, header: String) -> String {
        if let colonRange = header.range(of: ":") {
            let inlineText = String(header[colonRange.upperBound...]).trimmed
            if !inlineText.isEmpty {
                return inlineText
            }
        }

        let promptLines = prompt.components(separatedBy: .newlines)
        guard let headerIndex = promptLines.firstIndex(where: { $0.trimmed == header }) else {
            return prompt
        }

        let trailingText = promptLines
            .dropFirst(headerIndex + 1)
            .joined(separator: "\n")
            .trimmed

        return trailingText
    }

    private static func firstCodeFence(in text: String) -> String? {
        guard let start = text.range(of: "```") else { return nil }
        let searchStart = start.upperBound
        guard let end = text.range(of: "```", range: searchStart..<text.endIndex) else { return nil }

        let fencedText = String(text[searchStart..<end.lowerBound])
        let lines = fencedText.components(separatedBy: .newlines)
        if let firstLine = lines.first,
           firstLine.range(of: "^[A-Za-z0-9_+-]+$", options: .regularExpression) != nil {
            return lines.dropFirst().joined(separator: "\n")
        }
        return fencedText
    }
}