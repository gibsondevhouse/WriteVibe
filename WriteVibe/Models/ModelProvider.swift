//
//  ModelProvider.swift
//  WriteVibe
//

import Foundation

// MARK: - ModelProvider

/// Represents a first-party AI provider. Used to organise the model picker rail.
enum ModelProvider: String, CaseIterable, Identifiable {
    case local       = "Local"
    case anthropic   = "Anthropic"
    case openai      = "OpenAI"
    case google      = "Google"
    case perplexity  = "Perplexity"
    case deepseek    = "DeepSeek"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// SF Symbol name shown next to the provider name in SettingsView / tooltips.
    /// The picker rail intentionally omits icons — they live here for other contexts.
    var iconName: String {
        switch self {
        case .local:      return "desktopcomputer"
        case .anthropic:  return "sparkles"
        case .openai:     return "wand.and.stars"
        case .google:     return "atom"
        case .perplexity: return "globe"
        case .deepseek:   return "wind"
        }
    }

    /// Static catalog of models belonging to this provider.
    /// The Local provider's Ollama model list is dynamic at runtime and handled separately in the picker.
    var models: [AIModel] {
        switch self {
        case .local:      return [.ollama]
        case .anthropic:  return [.claudeHaiku, .claudeSonnet, .claudeOpus]
        case .openai:     return [.gpt4oMini, .gpt4o, .o3Mini]
        case .google:     return [.geminiFlash, .geminiPro]
        case .perplexity: return [.perplexitySonar, .perplexitySonarPro]
        case .deepseek:   return [.deepSeekR1, .deepSeekV3]
        }
    }
}

// MARK: - AIModel + provider

extension AIModel {
    /// Which provider this model belongs to.
    var provider: ModelProvider {
        switch self {
        case .ollama:                                  return .local
        case .claudeHaiku, .claudeSonnet, .claudeOpus: return .anthropic
        case .gpt4oMini, .gpt4o, .o3Mini:              return .openai
        case .geminiFlash, .geminiPro:                 return .google
        case .perplexitySonar, .perplexitySonarPro:   return .perplexity
        case .deepSeekR1, .deepSeekV3:                 return .deepseek
        }
    }
}
