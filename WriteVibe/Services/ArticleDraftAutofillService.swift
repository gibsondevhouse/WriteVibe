//
//  ArticleDraftAutofillService.swift
//  WriteVibe
//

import Foundation

struct ArticleDraftAutofillResult {
    let title: String?
    let subtitle: String?
    let tone: ArticleTone?
    let targetLength: ArticleLength?
}

protocol ArticleDraftAutofillServicing {
    func autofill(from summary: String) -> ArticleDraftAutofillResult
}

final class ArticleDraftAutofillService: ArticleDraftAutofillServicing {
    private let titleWordLimit = 8
    private let titleCharacterLimit = 68
    private let subtitleWordLimit = 16
    private let subtitleCharacterLimit = 120
    private let fillerPrefixes = [
        "the article is about ",
        "this article is about ",
        "the article explores ",
        "this article explores ",
        "the article examines ",
        "this article examines ",
        "the article discusses ",
        "this article discusses ",
        "the article covers ",
        "this article covers ",
        "in this article, ",
        "in this article ",
        "article about ",
        "an article about ",
        "this is about ",
        "it is about ",
        "about "
    ]

    private let weakHeadlineOpenings = [
        "understanding ",
        "exploring ",
        "introduction to ",
        "guide to ",
        "overview of ",
        "how to ",
        "what is ",
        "what are ",
        "why "
    ]

    private let subtitleExpansionLeads = [
        "What changes:",
        "Why it matters:",
        "The takeaway:",
        "In practice:"
    ]

    private let actionWords: Set<String> = [
        "accelerates", "boosts", "cuts", "drives", "expands", "improves", "increases", "reduces", "reshapes", "shifts", "slows", "strengthens", "transforms"
    ]

    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "how", "in", "into", "is", "it", "of", "on", "or", "that", "the", "their", "this", "to", "was", "what", "when", "where", "who", "why", "with"
    ]

    func autofill(from summary: String) -> ArticleDraftAutofillResult {
        let cleanedSummary = normalizedSummary(summary)
        guard !cleanedSummary.isEmpty else {
            return ArticleDraftAutofillResult(title: nil, subtitle: nil, tone: nil, targetLength: nil)
        }

        let title = inferTitle(from: cleanedSummary)
        let subtitle = inferSubtitle(from: cleanedSummary, title: title)
        let tone = inferTone(from: cleanedSummary)
        let length = inferLength(from: cleanedSummary)

        return ArticleDraftAutofillResult(
            title: title,
            subtitle: subtitle,
            tone: tone,
            targetLength: length
        )
    }

    private func inferTitle(from summary: String) -> String {
        let sentences = extractSentences(from: summary)
        let primarySentence = stripLeadingWeakOpenings(from: stripLeadingFiller(from: sentences.first ?? summary))
        let clauses = splitIntoClauses(primarySentence)
        let bestClause = clauses.max(by: { clauseScore($0) < clauseScore($1) }) ?? primarySentence

        let headlineSeed = stripLeadingWeakOpenings(from: bestClause)
        var words = tokenizeWords(headlineSeed)
        while let first = words.first, stopWords.contains(first.lowercased()) {
            words.removeFirst()
        }
        if words.isEmpty {
            words = tokenizeWords(primarySentence)
        }

        let candidate = words.prefix(titleWordLimit).joined(separator: " ")
        let compact = truncateAtWordBoundary(candidate, characterLimit: titleCharacterLimit, withEllipsis: false)
        let trimmed = compact.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'()[]{}"))
        return styledTitle(from: trimmed.isEmpty ? "Untitled Article" : trimmed)
    }

    private func inferSubtitle(from summary: String, title: String) -> String {
        let sentences = extractSentences(from: summary)
        var candidate: String?
        let titleTokenSet = Set(normalizedComparableTokens(title))

        if sentences.count > 1 {
            let trailing = sentences.dropFirst().joined(separator: " ")
            candidate = shapeSubtitleCandidate(from: trailing, titleTokenSet: titleTokenSet)
        } else {
            let singleSentence = stripLeadingWeakOpenings(from: stripLeadingFiller(from: sentences.first ?? summary))
            let clauses = splitIntoClauses(singleSentence)
            if clauses.count > 1 {
                candidate = shapeSubtitleCandidate(from: clauses.dropFirst().joined(separator: " "), titleTokenSet: titleTokenSet)
            } else {
                candidate = extractContextualSubtitle(from: singleSentence, title: title)
            }
        }

        if candidate == nil {
            candidate = "Why it matters: context, impact, and practical takeaways"
        }

        let prepared = truncateAtWordBoundary((candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines), characterLimit: subtitleCharacterLimit, withEllipsis: false)
        let deduped = avoidSubtitleDuplication(prepared, title: title)
        return deduped
    }

    private func normalizedSummary(_ summary: String) -> String {
        summary
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractSentences(from summary: String) -> [String] {
        let normalized = normalizedSummary(summary)
        guard !normalized.isEmpty else { return [] }

        let pieces = normalized
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return pieces
    }

    private func splitIntoClauses(_ sentence: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",:;-")
        let clauses = sentence
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return clauses.isEmpty ? [sentence] : clauses
    }

    private func stripLeadingFiller(from sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        for prefix in fillerPrefixes where lowercased.hasPrefix(prefix) {
            let dropCount = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
            let remainder = String(trimmed[dropCount...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return remainder.isEmpty ? trimmed : remainder
        }
        return trimmed
    }

    private func stripLeadingWeakOpenings(from sentence: String) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        for opening in weakHeadlineOpenings where lowercased.hasPrefix(opening) {
            let dropCount = trimmed.index(trimmed.startIndex, offsetBy: opening.count)
            let remainder = String(trimmed[dropCount...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return remainder.isEmpty ? trimmed : remainder
        }
        return trimmed
    }

    private func tokenizeWords(_ input: String) -> [String] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let separators = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-'")).inverted
        return trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func extractContextualSubtitle(from sentence: String, title: String) -> String? {
        let sentenceTokens = tokenizeWords(sentence)
        let titleTokenSet = Set(normalizedComparableTokens(title))
        guard !sentenceTokens.isEmpty, !titleTokenSet.isEmpty else {
            return nil
        }

        let contextualTokens = sentenceTokens.filter { token in
            !titleTokenSet.contains(token.lowercased())
        }

        guard contextualTokens.count >= 4 else {
            return nil
        }

        return shapeSubtitleCandidate(from: contextualTokens.prefix(subtitleWordLimit).joined(separator: " "), titleTokenSet: titleTokenSet)
    }

    private func shapeSubtitleCandidate(from source: String, titleTokenSet: Set<String>) -> String? {
        let cleaned = normalizedSummary(stripLeadingFiller(from: source))
        guard !cleaned.isEmpty else { return nil }

        let candidateTokens = tokenizeWords(cleaned)
        guard !candidateTokens.isEmpty else { return nil }

        let filteredTokens = candidateTokens.filter { token in
            !titleTokenSet.contains(token.lowercased())
        }

        let tokens = filteredTokens.count >= 5 ? filteredTokens : candidateTokens
        let compact = tokens.prefix(subtitleWordLimit).joined(separator: " ")
        guard !compact.isEmpty else { return nil }

        let leadIndex = stableLeadIndex(for: cleaned, tokenCount: tokens.count)
        let lead = subtitleExpansionLeads[leadIndex]
        return "\(lead) \(compact)"
    }

    private func stableLeadIndex(for text: String, tokenCount: Int) -> Int {
        let checksum = text.unicodeScalars.reduce(0) { partial, scalar in
            (partial + Int(scalar.value)) % 10_000
        }
        return (checksum + tokenCount) % subtitleExpansionLeads.count
    }

    private func clauseScore(_ clause: String) -> Int {
        let words = tokenizeWords(clause)
        let keywordCount = words.filter { !stopWords.contains($0.lowercased()) }.count
        let actionBoost = words.contains(where: { actionWords.contains($0.lowercased()) }) ? 4 : 0
        let lengthPenalty = abs(words.count - 6)
        let genericPenalty = weakHeadlineOpenings.contains(where: { clause.lowercased().hasPrefix($0) }) ? 3 : 0
        return (keywordCount * 3) + actionBoost - lengthPenalty - genericPenalty
    }

    private func truncateAtWordBoundary(_ text: String, characterLimit: Int, withEllipsis: Bool) -> String {
        guard text.count > characterLimit else { return text }
        let index = text.index(text.startIndex, offsetBy: characterLimit)
        var prefix = String(text[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastSpace = prefix.lastIndex(of: " "), prefix.distance(from: lastSpace, to: prefix.endIndex) > 1 {
            prefix = String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard withEllipsis else { return prefix }
        return prefix + "..."
    }

    private func styledTitle(from title: String) -> String {
        let smallWords: Set<String> = ["a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"]
        let tokens = title.split(separator: " ").map(String.init)

        let styled = tokens.enumerated().map { index, token in
            let lower = token.lowercased()
            if index > 0 && smallWords.contains(lower) {
                return lower
            }
            return capitalizeToken(token)
        }
        return styled.joined(separator: " ")
    }

    private func capitalizeToken(_ token: String) -> String {
        if token.count <= 5 && token == token.uppercased() {
            return token
        }

        let parts = token.split(separator: "-").map(String.init)
        let capitalizedParts = parts.map { part -> String in
            let lower = part.lowercased()
            guard let first = lower.first else { return part }
            return String(first).uppercased() + lower.dropFirst()
        }
        return capitalizedParts.joined(separator: "-")
    }

    private func avoidSubtitleDuplication(_ subtitle: String, title: String) -> String {
        guard !subtitle.isEmpty else { return subtitle }
        if !isTooSimilar(subtitle, title) {
            return subtitle
        }

        let fallback = "Why it matters: context, impact, and practical takeaways"
        if !isTooSimilar(fallback, title) {
            return fallback
        }
        return ""
    }

    private func isTooSimilar(_ lhs: String, _ rhs: String) -> Bool {
        let leftTokens = normalizedComparableTokens(lhs)
        let rightTokens = normalizedComparableTokens(rhs)

        if leftTokens.isEmpty || rightTokens.isEmpty {
            return lhs.caseInsensitiveCompare(rhs) == .orderedSame
        }

        let leftJoined = leftTokens.joined(separator: " ")
        let rightJoined = rightTokens.joined(separator: " ")
        if leftJoined == rightJoined {
            return true
        }
        if leftJoined.contains(rightJoined) || rightJoined.contains(leftJoined) {
            return true
        }

        let leftSet = Set(leftTokens)
        let rightSet = Set(rightTokens)
        let intersection = leftSet.intersection(rightSet).count
        let union = leftSet.union(rightSet).count
        let jaccard = union == 0 ? 0.0 : Double(intersection) / Double(union)
        let overlap = Double(intersection) / Double(min(leftSet.count, rightSet.count))

        let leftBigrams = Set(ngrams(from: leftTokens, n: 2))
        let rightBigrams = Set(ngrams(from: rightTokens, n: 2))
        let bigramIntersection = leftBigrams.intersection(rightBigrams).count
        let bigramBase = max(1, min(leftBigrams.count, rightBigrams.count))
        let bigramOverlap = Double(bigramIntersection) / Double(bigramBase)

        return jaccard >= 0.55 || overlap >= 0.75 || bigramOverlap >= 0.5
    }

    private func ngrams(from tokens: [String], n: Int) -> [String] {
        guard n > 1, tokens.count >= n else { return [] }
        return (0...(tokens.count - n)).map { index in
            tokens[index..<(index + n)].joined(separator: " ")
        }
    }

    private func normalizedComparableTokens(_ text: String) -> [String] {
        tokenizeWords(text.lowercased()).filter { !stopWords.contains($0) }
    }

    private func inferTone(from summary: String) -> ArticleTone {
        let lowercased = summary.lowercased()

        if lowercased.contains("technical") || lowercased.contains("architecture") || lowercased.contains("implementation") {
            return .technical
        }
        if lowercased.contains("story") || lowercased.contains("journey") || lowercased.contains("narrative") {
            return .narrative
        }
        if lowercased.contains("convince") || lowercased.contains("argument") || lowercased.contains("why") {
            return .persuasive
        }
        if lowercased.contains("funny") || lowercased.contains("humor") || lowercased.contains("lighthearted") {
            return .humorous
        }

        return .informative
    }

    private func inferLength(from summary: String) -> ArticleLength {
        let words = summary.split(whereSeparator: { $0.isWhitespace }).count

        if words <= 12 {
            return .brief
        }
        if words <= 24 {
            return .short
        }
        if words <= 45 {
            return .medium
        }
        return .long
    }
}
