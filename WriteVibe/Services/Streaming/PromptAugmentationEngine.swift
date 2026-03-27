//
//  PromptAugmentationEngine.swift
//  WriteVibe
//

import Foundation

/// Builds augmented system prompts from capability chip selections and search context.
/// Owns all allowlists and prompt sanitization logic.
@MainActor
final class PromptAugmentationEngine {

    // MARK: - Capability Chip Allowlists

    static let validTones: Set<String> = ["Balanced", "Professional", "Creative", "Concise"]
    static let validLengths: Set<String> = ["Normal", "Short", "Long"]
    static let validFormats: Set<String> = ["Markdown", "Plain Text", "JSON"]

    // MARK: - Prompt Sanitization

    /// Strips control characters, prompt delimiters, and truncates to prevent prompt injection via external content.
    static func sanitizeForPrompt(_ text: String, maxLength: Int = 5000) -> String {
        var scalars = String.UnicodeScalarView()
        for s in text.unicodeScalars where s.value >= 32 || s.value == 9 || s.value == 10 {
            scalars.append(s)
        }
        var sanitized = String(scalars)

        for pattern in ["---", "```system", "```instruction", "### Instructions", "### System", "[INST]", "<<SYS>>", "<|im_start|>", "<|im_end|>"] {
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "")
        }

        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }
        return sanitized
    }

    // MARK: - Capability Chip Augmentation

    /// Augments the base system prompt with tone, length, format, and memory instructions.
    func augmentWithCapabilities(
        basePrompt: String,
        tone: String,
        length: String,
        format: String,
        isMemoryEnabled: Bool
    ) -> String {
        var prompt = basePrompt

        let safeTone = Self.validTones.contains(tone) ? tone : "Balanced"
        let safeLength = Self.validLengths.contains(length) ? length : "Normal"
        let safeFormat = Self.validFormats.contains(format) ? format : "Markdown"

        if safeTone != "Balanced" {
            switch safeTone {
            case "Professional":
                prompt += "\n\nTone: Maintain a formal, authoritative, and professional tone. Use industry-standard terminology where appropriate."
            case "Creative":
                prompt += "\n\nTone: Use an imaginative, expressive, and engaging tone. Feel free to use metaphors and creative phrasing."
            case "Concise":
                prompt += "\n\nTone: Be extremely brief and to the point. Avoid any filler or unnecessary explanation."
            default:
                break
            }
        }

        if safeLength != "Normal" {
            switch safeLength {
            case "Short":
                prompt += "\n\nLength: Keep the response very brief, ideally under 100 words."
            case "Long":
                prompt += "\n\nLength: Provide a detailed and comprehensive response, covering all aspects in depth."
            default:
                break
            }
        }

        if safeFormat != "Markdown" {
            switch safeFormat {
            case "Plain Text":
                prompt += "\n\nFormat: Do not use any markdown formatting. Output raw plain text only."
            case "JSON":
                prompt += "\n\nFormat: Structure your entire response as a valid JSON object."
            default:
                break
            }
        }

        if isMemoryEnabled {
            prompt += "\n\nMemory: Recall relevant details from previous turns and user preferences to ensure continuity."
        }

        return prompt
    }

    // MARK: - Search Context Augmentation

    /// Appends serialized search results to the prompt with citation instructions.
    func appendSearchResults(
        _ results: [SearchResult],
        to prompt: String,
        searchModel: String
    ) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(results),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return prompt + "\n\nSearch: Failed to encode search results to JSON. Do not claim web verification."
        }
        let sanitizedContext = Self.sanitizeForPrompt(jsonString)
        return prompt + "\n\nWebResearchContext (from \(searchModel)):\n\(sanitizedContext)\n\nUse the provided JSON WebResearchContext. For each fact you state that comes from this context, append an inline citation like [Source: {URL}]."
    }

    /// Appends local-model grounding instruction.
    func appendLocalGrounding(to prompt: String) -> String {
        prompt + "\n\nIMPORTANT: Your only sources for dates, names, titles, and roles are the WebResearchContext above. If a fact is not in the context, say \"I don't have current data on this\" rather than guessing."
    }
}
