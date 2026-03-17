//
//  StreamingService.swift
//  WriteVibe
//

import Foundation
import SwiftData
import Security // Import Security framework for Keychain access

@MainActor
@Observable
final class StreamingService {

    private let conversationService: ConversationService
    private let searchProvider: OpenRouterService

    init(conversationService: ConversationService, searchProvider: OpenRouterService) {
        self.conversationService = conversationService
        self.searchProvider = searchProvider
    }

    /// Streams an AI reply into a placeholder message using the given provider and model name.
    func streamReply(
        provider: AIStreamingProvider,
        modelName: String,
        conversationId: UUID,
        context: ModelContext,
        isSearchEnabled: Bool = false,
        tone: String = "Balanced",
        length: String = "Normal",
        format: String = "Markdown",
        isMemoryEnabled: Bool = true
    ) async throws {
        guard let conv = conversationService.fetch(conversationId, context: context) else { return }

        let contextMessages = conv.messages
            .filter { !$0.content.isEmpty }
            .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.content] }

        let placeholder = Message(role: .assistant, content: "", modelUsed: modelName)
        conversationService.appendMessage(placeholder, to: conversationId, context: context)

        // Augment system prompt based on capability chips
        var augmentedPrompt = writeVibeSystemPrompt
        
        if tone != "Balanced" {
            switch tone {
            case "Professional":
                augmentedPrompt += "\n\nTone: Maintain a formal, authoritative, and professional tone. Use industry-standard terminology where appropriate."
            case "Creative":
                augmentedPrompt += "\n\nTone: Use an imaginative, expressive, and engaging tone. Feel free to use metaphors and creative phrasing."
            case "Concise":
                augmentedPrompt += "\n\nTone: Be extremely brief and to the point. Avoid any filler or unnecessary explanation."
            default:
                augmentedPrompt += "\n\nTone: Respond in a \(tone.lowercased()) tone."
            }
        }
        
        if length != "Normal" {
            switch length {
            case "Short":
                augmentedPrompt += "\n\nLength: Keep the response very brief, ideally under 100 words."
            case "Long":
                augmentedPrompt += "\n\nLength: Provide a detailed and comprehensive response, covering all aspects in depth."
            default:
                augmentedPrompt += "\n\nLength: Make your response \(length.lowercased())."
            }
        }
        
        if format != "Markdown" {
            switch format {
            case "Plain Text":
                augmentedPrompt += "\n\nFormat: Do not use any markdown formatting. Output raw plain text only."
            case "JSON":
                augmentedPrompt += "\n\nFormat: Structure your entire response as a valid JSON object."
            default:
                augmentedPrompt += "\n\nFormat: Format your response as \(format)."
            }
        }
        
        if isSearchEnabled {
            let selectedModelIsSearchNative = modelName.hasPrefix("perplexity/sonar")
            let searchLayerModel = selectedModelIsSearchNative
                ? modelName
                : (AIModel.perplexitySonarPro.openRouterModelID ?? "perplexity/sonar-pro")

            if selectedModelIsSearchNative {
                augmentedPrompt += "\n\nSearch: Use your built-in web retrieval. Ground factual claims in retrieved sources and include citations/links when possible. If retrieval fails, say that clearly instead of inventing details."
            } else if let query = conv.messages.reversed().first(where: { $0.role == .user && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.content {
                do {
                    // Fetch web context, which now includes API key check and structured parsing
                    if let searchResults = try await fetchWebSearchContext(query: query, searchModel: searchLayerModel) {
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = .prettyPrinted
                        if let jsonData = try? encoder.encode(searchResults) {
                            if let jsonString = String(data: jsonData, encoding: .utf8) {
                                augmentedPrompt += "\n\nWebResearchContext (from \(searchLayerModel)):\n\(jsonString)\n\nUse the provided JSON WebResearchContext. For each fact you state that comes from this context, append an inline citation like [Source: {URL}]."
                            } else {
                                augmentedPrompt += "\n\nSearch: Could not format web search results as JSON. Do not claim web verification."
                            }
                        } else {
                            augmentedPrompt += "\n\nSearch: Failed to encode search results to JSON. Do not claim web verification."
                        }
                    } else {
                        // This branch is hit if fetchWebSearchContext returns nil without throwing
                        augmentedPrompt += "\n\nSearch: The web search layer returned no usable findings. Do not claim verified web results."
                    }
                } catch {
                    // Catch errors from fetchWebSearchContext, including missing API key
                    augmentedPrompt += "\n\nSearch: The web search layer is unavailable right now (\(error.localizedDescription)). Do not claim web verification."
                }
            } else {
                augmentedPrompt += "\n\nSearch: No user query was available for web retrieval. Do not claim web verification."
            }
        }
        
        // Add grounding mode instruction for local models when search is enabled
        if isSearchEnabled {
            let selectedModel = AIModel(rawValue: modelName) ?? .ollama // Fallback to ollama if modelName is not found
            if selectedModel.isLocal {
                augmentedPrompt += "\n\nIMPORTANT: Your only sources for dates, names, titles, and roles are the WebResearchContext above. If a fact is not in the context, say \"I don't have current data on this\" rather than guessing."
            }
        }

        if isMemoryEnabled {
            augmentedPrompt += "\n\nMemory: Recall relevant details from previous turns and user preferences to ensure continuity."
        }

        var tokenBuffer = ""
        var tokenCount  = 0

        let stream = provider.stream(
            model: modelName,
            messages: contextMessages,
            systemPrompt: augmentedPrompt
        )

        for try await token in stream {
            tokenBuffer += token
            tokenCount  += 1
            if tokenCount >= AppConstants.tokenBatchSize {
                placeholder.content += tokenBuffer
                tokenBuffer = ""
                tokenCount  = 0
            }
        }

        if !tokenBuffer.isEmpty { placeholder.content += tokenBuffer }
        placeholder.tokenCount = placeholder.content.count / 4
        if let c = conversationService.fetch(conversationId, context: context) { c.updatedAt = Date() }
        try? context.save()
    }

    /// Fetches web search context, parses it into SearchResult objects, and returns them.
    /// Includes API key check and handles potential parsing errors.
    private func fetchWebSearchContext(query: String, searchModel: String) async throws -> [SearchResult]? {
        // Check for OpenRouter API key presence
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
            if collectedString.count >= 8_000 { // Limit the collected string size
                break
            }
        }

        let trimmedResults = collectedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedResults.isEmpty else { return nil }

        // Parse the bulleted list into SearchResult objects
        var searchResults: [SearchResult] = []
        let lines = trimmedResults.split(whereSeparator: \.isNewline)

        for line in lines {
            let lineString = String(line)
            // Attempt to parse using regex. This is a common format but might need adjustment
            // based on actual Ollama/OpenRouter output for search.
            // Regex: Matches "**Title** (URL) - Snippet"
            let regex = try? NSRegularExpression(pattern: #"^\*\*(.+?)\*\*\s+\((.+?)\)\s*-\s*(.+)"#)
            
            if let match = regex?.firstMatch(in: lineString, options: [], range: NSRange(location: 0, length: lineString.utf16.count)),
               let titleRange = Range(match.range(at: 1), in: lineString),
               let urlRange = Range(match.range(at: 2), in: lineString),
               let snippetRange = Range(match.range(at: 3), in: lineString) {
                
                let title = String(lineString[titleRange])
                let urlString = String(lineString[urlRange])
                let snippet = String(lineString[snippetRange])

                if let url = URL(string: urlString) {
                    searchResults.append(SearchResult(title: title, url: url, snippet: snippet))
                }
            } else {
                // Log or handle lines that don't match the expected format if necessary
                print("Warning: Could not parse search result line: \(lineString)")
            }
        }
        
        return searchResults.isEmpty ? nil : searchResults
    }
}
