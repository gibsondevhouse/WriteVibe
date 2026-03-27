//
//  WebSearchContextProvider.swift
//  WriteVibe
//

import Foundation

/// Fetches web search context via a search-capable AI provider and parses structured results.
@MainActor
final class WebSearchContextProvider {

    private let searchProvider: OpenRouterService

    init(searchProvider: OpenRouterService) {
        self.searchProvider = searchProvider
    }

    /// Fetches web search results for the given query using the specified model.
    /// Returns parsed `SearchResult` objects, or `nil` if no results were found.
    func fetchContext(query: String, searchModel: String) async throws -> [SearchResult]? {
        guard KeychainService.load(key: "openrouter_api_key") != nil else {
            throw WriteVibeError.missingAPIKey(provider: "OpenRouter")
        }

        let searchInstruction = """
        You are WriteVibe's web research layer. Search for current, reliable information and return concise findings with source links.
        Output format:
        - Bullet list of key findings.
        - Each finding should start with a title in bold, followed by its URL in parentheses, and then the snippet.
        - Example format: **Search Result Title** (https://example.com/link) - This is a brief summary of the finding.
        - Prefer recent and authoritative sources.
        - If information is uncertain or conflicting, say so.
        """

        let searchMessages = [["role": "user", "content": query]]
        let searchStream = searchProvider.stream(
            model: searchModel,
            messages: searchMessages,
            systemPrompt: searchInstruction
        )

        var collectedString = ""
        for try await token in searchStream {
            collectedString += token
            if collectedString.count >= 8_000 { break }
        }

        let trimmedResults = collectedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResults.isEmpty else { return nil }

        return parseSearchResults(trimmedResults)
    }

    // MARK: - Parsing

    /// Parses a bulleted list of search results into `SearchResult` objects.
    /// Expected format: `**Title** (URL) - Snippet`
    private func parseSearchResults(_ text: String) -> [SearchResult]? {
        var searchResults: [SearchResult] = []
        let lines = text.split(whereSeparator: \.isNewline)
        let regex = try? NSRegularExpression(pattern: #"^\*\*(.+?)\*\*\s+\((.+?)\)\s*-\s*(.+)"#)

        for line in lines {
            let lineString = String(line)
            guard let match = regex?.firstMatch(
                in: lineString,
                options: [],
                range: NSRange(location: 0, length: lineString.utf16.count)
            ),
            let titleRange = Range(match.range(at: 1), in: lineString),
            let urlRange = Range(match.range(at: 2), in: lineString),
            let snippetRange = Range(match.range(at: 3), in: lineString) else {
                continue
            }

            let title = String(lineString[titleRange])
            let urlString = String(lineString[urlRange])
            let snippet = String(lineString[snippetRange])

            if let url = URL(string: urlString) {
                searchResults.append(SearchResult(title: title, url: url, snippet: snippet))
            }
        }

        return searchResults.isEmpty ? nil : searchResults
    }
}
