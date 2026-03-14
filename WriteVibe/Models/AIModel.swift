//
//  AIModel.swift
//  WriteVibe
//

import Foundation

enum AIModel: String, CaseIterable, Identifiable, Codable {
    case ollama             = "Ollama"
    case appleIntelligence  = "Apple Intelligence"
    // Anthropic (via OpenRouter)
    case claudeHaiku       = "Claude Haiku"
    case claudeSonnet      = "Claude Sonnet"
    case claudeOpus        = "Claude Opus"
    // OpenAI (via OpenRouter)
    case gpt4oMini         = "GPT-4o Mini"
    case gpt4o             = "GPT-4o"
    case o3Mini            = "o3 Mini"
    // Google (via OpenRouter)
    case geminiFlash       = "Gemini Flash"
    case geminiPro         = "Gemini Pro"
    // Perplexity (via OpenRouter)
    case perplexitySonar    = "Sonar"
    case perplexitySonarPro = "Sonar Pro"
    // DeepSeek (via OpenRouter)
    case deepSeekR1        = "DeepSeek R1"
    case deepSeekV3        = "DeepSeek V3"

    var id: String { rawValue }

    // MARK: - Codable

    /// Custom decoder that falls back to `.ollama` when a persisted raw value no longer exists
    /// (e.g. "Apple Intelligence" from builds before it was removed). Without this, SwiftData
    /// throws a fatal decoding error on launch for any conversation saved with a removed model.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let value = AIModel(rawValue: raw) {
            self = value
        } else {
            self = .ollama
        }
    }

    var subtitle: String {
        switch self {
        case .ollama:             return "Local · Private · Free"
        case .appleIntelligence:  return "Fast · On-device · Private"
        case .claudeHaiku:        return "Fast · Affordable"
        case .claudeSonnet:       return "Balanced · Capable"
        case .claudeOpus:         return "Most powerful"
        case .gpt4oMini:          return "Fast · Affordable"
        case .gpt4o:              return "Versatile · Smart"
        case .o3Mini:             return "Reasoning model"
        case .geminiFlash:        return "Fast · Multimodal"
        case .geminiPro:          return "Long context"
        case .perplexitySonar:    return "Web search · Fast"
        case .perplexitySonarPro: return "Deep research · Citations"
        case .deepSeekR1:         return "Reasoning · Open-source"
        case .deepSeekV3:         return "Efficient · Open-source"
        }
    }

    /// Curated one-line product-facing description used in the model picker.
    var tagline: String {
        switch self {
        case .ollama:             return "Your private, offline assistant"
        case .appleIntelligence:  return "Apple's on-device foundation model"
        case .claudeHaiku:        return "Quick answers, low cost"
        case .claudeSonnet:       return "Strong writing and reasoning"
        case .claudeOpus:         return "Maximum depth and nuance"
        case .gpt4oMini:          return "Fast, cost-effective responses"
        case .gpt4o:              return "Versatile intelligence for complex tasks"
        case .o3Mini:             return "Step-by-step reasoning"
        case .geminiFlash:        return "Fast multimodal responses"
        case .geminiPro:          return "Very long documents and context"
        case .perplexitySonar:    return "Real-time web answers"
        case .perplexitySonarPro: return "Deep web research with citations"
        case .deepSeekR1:         return "Open-source reasoning model"
        case .deepSeekV3:         return "Efficient open-source generation"
        }
    }

    /// Extended use-case description shown in the model picker detail card on hover.
    var useCaseDescription: String {
        switch self {
        case .ollama:
            return "Runs entirely on your Mac — no data ever leaves your device. Best for privacy-sensitive drafts, offline work, or experimenting without API costs."
        case .appleIntelligence:
            return "Leverages on-device Apple Intelligence for fast, private, and offline-capable generation. Optimized for everyday writing tasks like summarization and drafting."
        case .claudeHaiku:
            return "Anthropic's fastest, most affordable model. Ideal for short-form tasks: quick edits, email drafts, summarisation, and any flow where speed matters more than depth."
        case .claudeSonnet:
            return "Anthropic's balanced workhorse. Excels at long-form writing, structured arguments, code explanation, and nuanced feedback — the go-to for most serious writing tasks."
        case .claudeOpus:
            return "Anthropic's most capable model. Use it for complex analysis, difficult rewrites, multi-layered arguments, or whenever the stakes of the output are high."
        case .gpt4oMini:
            return "OpenAI's compact, fast model. Good for quick generation, first drafts, and cost-effective iteration when you need to send many messages."
        case .gpt4o:
            return "OpenAI's flagship multimodal model. Strong across a wide range of writing and reasoning tasks; handles images, PDFs, and nuanced long-context prompts."
        case .o3Mini:
            return "OpenAI's compact reasoning model. Breaks down problems step-by-step before writing — useful for technical explanations, outlines, logical arguments, and structured plans."
        case .geminiFlash:
            return "Google's fastest multimodal model. Great for high-volume generation, image-assisted drafts, and situations where turnaround time is critical."
        case .geminiPro:
            return "Google's most powerful model with a very large context window. Best for editing extremely long documents, synthesising multiple sources, or extended conversations."
        case .perplexitySonar:
            return "Perplexity's search-augmented model. Answers questions grounded in live web results — useful for fact-checking, current events, or researching before you write."
        case .perplexitySonarPro:
            return "Perplexity's deep-research model. Produces cited, multi-source answers. Use for in-depth research, journalism-style briefs, and any draft that needs verifiable sources."
        case .deepSeekR1:
            return "DeepSeek's open-source reasoning model. Traces its thinking before answering — effective for technical writing, logical structure, and breaking down complex ideas."
        case .deepSeekV3:
            return "DeepSeek's efficient open-source generation model. Competitive quality at lower cost; solid for general writing, editing, and creative tasks."
        }
    }

    var icon: String {
        switch self {
        case .ollama:                                  return "desktopcomputer"
        case .appleIntelligence:                       return "desktopcomputer"
        case .claudeHaiku, .claudeSonnet, .claudeOpus: return "sparkles"
        case .gpt4oMini, .gpt4o, .o3Mini:              return "wand.and.stars"
        case .geminiFlash, .geminiPro:                 return "atom"
        case .perplexitySonar, .perplexitySonarPro:    return "globe"
        case .deepSeekR1, .deepSeekV3:                 return "wind"
        }
    }

    var isLocal: Bool {
        self == .ollama || self == .appleIntelligence
    }

    var requiresAPIKey: Bool {
        !isLocal
    }

    /// Returns the OpenRouter model identifier for cloud models, nil for local models.
    var openRouterModelID: String? {
        switch self {
        case .claudeHaiku:        return "anthropic/claude-3-5-haiku"
        case .claudeSonnet:       return "anthropic/claude-3-7-sonnet"
        case .claudeOpus:         return "anthropic/claude-3-opus"
        case .gpt4oMini:          return "openai/gpt-4o-mini"
        case .gpt4o:              return "openai/gpt-4o"
        case .o3Mini:             return "openai/o3-mini"
        case .geminiFlash:        return "google/gemini-2.0-flash-001"
        case .geminiPro:          return "google/gemini-2.5-pro-preview"
        case .perplexitySonar:    return "perplexity/sonar"
        case .perplexitySonarPro: return "perplexity/sonar-pro"
        case .deepSeekR1:         return "deepseek/deepseek-r1"
        case .deepSeekV3:         return "deepseek/deepseek-chat"
        case .ollama:             return nil
        case .appleIntelligence:  return nil
        }
    }

    var displayName: String {
        switch self {
        case .ollama:             return "Ollama"
        case .appleIntelligence:  return "Apple Intelligence"
        case .claudeHaiku:        return "Claude Haiku"
        case .claudeSonnet:       return "Claude Sonnet"
        case .claudeOpus:         return "Claude Opus"
        case .gpt4oMini:          return "GPT-4o Mini"
        case .gpt4o:              return "GPT-4o"
        case .o3Mini:             return "o3 Mini"
        case .geminiFlash:        return "Gemini Flash"
        case .geminiPro:          return "Gemini Pro"
        case .perplexitySonar:    return "Sonar"
        case .perplexitySonarPro: return "Sonar Pro"
        case .deepSeekR1:         return "DeepSeek R1"
        case .deepSeekV3:         return "DeepSeek V3"
        }
    }
}
