//
//  ArticleAIService.swift
//  WriteVibe
//
//  Sends an article to an AI model and receives structured ProposedEdits.
//  Uses a strict JSON-schema prompt so the model returns operations, not
//  raw prose — the editor never applies raw completion strings.
//

import Foundation

// MARK: - ArticleAIService

@MainActor
enum ArticleAIService {

    // MARK: - Edit instruction prompt

    /// Builds the system prompt for the article editing task.
    private static var systemPrompt: String {
        """
        You are an expert copy editor and journalist. The user will send you an article in a structured JSON block format.
        Your task is to improve it for clarity, flow, and journalistic quality.

        You MUST respond ONLY with a valid JSON object of shape:
        {
          "summary": "<one sentence describing what you changed and why>",
          "operations": [
            { "op": "replace", "blockID": "<uuid>", "oldText": "<exact words>", "newText": "<replacement words>", "reason": "<why>" },
            { "op": "insert",  "blockID": "<uuid>", "afterText": "<exact words before insertion>", "text": "<words to insert>", "reason": "<why>" },
            { "op": "delete",  "blockID": "<uuid>", "text": "<exact words to delete>", "reason": "<why>" }
          ]
        }

        Rules:
        - Only propose changes that genuinely improve the writing.
        - Keep the author's voice. Do not rewrite entire paragraphs.
        - "oldText" and "text" for delete/insert must be verbatim substrings of the block content.
        - Return no prose outside the JSON object.
        """
    }

    // MARK: - Public API

    /// Requests AI editing proposals for the given article blocks.
    /// Parses the JSON response into `ProposedEdits` with structured operations.
    static func proposeEdits(
        blocks: [ArticleBlock],
        modelID: String,
        provider: AIStreamingProvider? = nil
    ) async throws -> ProposedEdits {
        let provider = provider ?? OpenRouterService()
        let articleJSON = buildArticleJSON(blocks: blocks)
        let userMessage = "Please edit this article:\n\n\(articleJSON)"

        var responseText = ""
        let stream = provider.stream(
            model: modelID,
            messages: [["role": "user", "content": userMessage]],
            systemPrompt: systemPrompt
        )
        for try await token in stream {
            responseText += token
        }

        return try parseProposedEdits(from: responseText, blocks: blocks)
    }

    // MARK: - JSON serialisation

    private static func buildArticleJSON(blocks: [ArticleBlock]) -> String {
        let sorted = blocks.sorted { $0.position < $1.position }
        let dicts: [[String: String]] = sorted.map { block in
            var typeLabel: String
            switch block.blockType {
            case .paragraph:      typeLabel = "paragraph"
            case .heading(let l): typeLabel = "h\(l)"
            case .blockquote:     typeLabel = "blockquote"
            case .code:           typeLabel = "code"
            case .image:          typeLabel = "image"
            }
            return ["id": block.id.uuidString, "type": typeLabel, "content": block.content]
        }
        let data = (try? JSONSerialization.data(withJSONObject: dicts, options: .prettyPrinted)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    // MARK: - Response parsing

    private static func parseProposedEdits(
        from responseText: String,
        blocks: [ArticleBlock]
    ) throws -> ProposedEdits {
        // Extract the JSON object from the response — the model may wrap it in markdown fences
        let jsonString = extractJSON(from: responseText)
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Return an empty proposal rather than crashing — model may have misbehaved
            return ProposedEdits(operations: [], summary: "Could not parse AI response.")
        }

        let summary = root["summary"] as? String
        let rawOps  = root["operations"] as? [[String: Any]] ?? []
        let blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id.uuidString, $0) })

        var ops: [ProposedBlockEdit] = []
        for op in rawOps {
            guard let opType  = op["op"] as? String,
                  let blockID = op["blockID"] as? String,
                  let block   = blockMap[blockID]
            else { continue }

            let reason = op["reason"] as? String
            let content = block.content

            switch opType {
            case "replace":
                guard let oldText = op["oldText"] as? String,
                      let newText = op["newText"] as? String,
                      let range   = content.range(of: oldText)
                else { continue }
                ops.append(.replace(blockID: block.id, range: range, newText: newText, reason: reason))

            case "insert":
                guard let text       = op["text"] as? String,
                      let afterText  = op["afterText"] as? String,
                      let afterRange = content.range(of: afterText)
                else { continue }
                ops.append(.insert(blockID: block.id, at: afterRange.upperBound, text: " " + text, reason: reason))

            case "delete":
                guard let text  = op["text"] as? String,
                      let range = content.range(of: text)
                else { continue }
                ops.append(.delete(blockID: block.id, range: range, reason: reason))

            default:
                continue
            }
        }

        return ProposedEdits(operations: ops, summary: summary)
    }

    private static func extractJSON(from text: String) -> String {
        // Strip ```json ... ``` fences if the model wrapped its output
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }
}
