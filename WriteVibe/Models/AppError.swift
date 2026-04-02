//
//  AppError.swift
//  WriteVibe
//

import Foundation

struct RuntimeIssue: Equatable, Sendable {
    let title: String
    let message: String
    let nextStep: String

    var guidanceText: String {
        "\(message) Next step: \(nextStep)"
    }

    static func modelContextUnavailable() -> RuntimeIssue {
        RuntimeIssue(
            title: "Workspace not ready",
            message: "WriteVibe is still attaching its local data store.",
            nextStep: "Wait a moment, then retry. If it keeps happening, relaunch the app before continuing."
        )
    }

    static func dataMigrationFailed(_ detail: String) -> RuntimeIssue {
        RuntimeIssue(
            title: "Local data needs attention",
            message: "WriteVibe could not finish a startup migration: \(detail)",
            nextStep: "Restart the app before editing data again. If the same migration fails again, inspect the logs before continuing."
        )
    }

    static func appleIntelligenceUnavailable() -> RuntimeIssue {
        RuntimeIssue(
            title: "Apple Intelligence unavailable",
            message: "This conversation cannot run with Apple Intelligence in the current app configuration.",
            nextStep: "Switch to Ollama or a cloud model in the picker, then resend your message."
        )
    }

    static func ollamaModelSelectionRequired() -> RuntimeIssue {
        RuntimeIssue(
            title: "Select an Ollama model",
            message: "This conversation is set to Ollama, but no installed model is selected.",
            nextStep: "Open Settings, choose or install an Ollama model, then resend your message."
        )
    }

    static func modelConfigurationIncomplete() -> RuntimeIssue {
        RuntimeIssue(
            title: "Model setup incomplete",
            message: "The selected model does not have a runnable provider configuration yet.",
            nextStep: "Switch to another model, or finish provider setup in Settings before retrying."
        )
    }

    static func articleEditFailure(_ detail: String) -> RuntimeIssue {
        RuntimeIssue(
            title: "AI edit unavailable",
            message: "WriteVibe could not prepare article edits: \(detail)",
            nextStep: "Retry AI Edit. If it fails again, switch models or review your provider settings."
        )
    }

    static func unexpectedRequestFailure(_ detail: String) -> RuntimeIssue {
        RuntimeIssue(
            title: "Request failed",
            message: "WriteVibe could not finish the response: \(detail)",
            nextStep: "Retry the request. If it fails again, switch models or review your provider settings."
        )
    }
}

enum WriteVibeError: Error, LocalizedError {
    case network(underlying: Error)
    case apiError(provider: String, statusCode: Int, message: String?)
    case missingAPIKey(provider: String)
    case modelUnavailable(name: String)
    case localSearchUnavailable(reason: String)
    case generationFailed(reason: String)
    case decodingFailed(context: String)
    case exportFailed(reason: String)
    case persistenceFailed(operation: String)
    case cancelled

    var runtimeIssue: RuntimeIssue {
        switch self {
        case .network(let underlying):
            return RuntimeIssue(
                title: "Connection problem",
                message: "WriteVibe could not reach the provider: \(underlying.localizedDescription)",
                nextStep: "Check your network connection, then retry. If it keeps failing, switch providers or review your API settings."
            )
        case .apiError(let provider, let statusCode, let message):
            return RuntimeIssue(
                title: "\(provider) request failed",
                message: Self.providerFailureMessage(provider: provider, statusCode: statusCode, message: message),
                nextStep: Self.providerRecoveryStep(provider: provider, statusCode: statusCode)
            )
        case .missingAPIKey(let provider):
            return RuntimeIssue(
                title: "\(provider) API key required",
                message: Self.missingAPIKeyMessage(provider: provider),
                nextStep: Self.missingAPIKeyNextStep(provider: provider)
            )
        case .modelUnavailable(let name):
            return RuntimeIssue(
                title: "Model unavailable",
                message: "\(name) is not available right now.",
                nextStep: "Confirm the model is installed and the provider is running, or switch models and retry."
            )
        case .localSearchUnavailable(let reason):
            return RuntimeIssue(
                title: "Search unavailable",
                message: "Web search is unavailable for this Ollama request because \(reason).",
                nextStep: "Turn off Search and resend your prompt, or add an OpenRouter API key in Settings > Cloud API Keys."
            )
        case .generationFailed(let reason):
            return RuntimeIssue(
                title: "Response failed",
                message: "The provider stopped before finishing the response: \(reason)",
                nextStep: "Retry the request. If it repeats, switch models or review provider setup in Settings."
            )
        case .decodingFailed(let context):
            return RuntimeIssue(
                title: "Response could not be read",
                message: "WriteVibe could not decode the provider response: \(context)",
                nextStep: "Retry once. If the same response keeps failing, switch models and capture the failing sample for QA."
            )
        case .exportFailed(let reason):
            return RuntimeIssue(
                title: "Export failed",
                message: "WriteVibe could not export this content: \(reason)",
                nextStep: "Choose a different save location or filename, then retry the export."
            )
        case .persistenceFailed(let operation):
            return RuntimeIssue(
                title: "Save failed",
                message: "WriteVibe could not save data during \(operation).",
                nextStep: "Retry the action. If it fails again, restart the app before making more edits."
            )
        case .cancelled:
            return RuntimeIssue(
                title: "Request stopped",
                message: "The current operation was cancelled before completion.",
                nextStep: "Resend the request when you are ready to continue."
            )
        }
    }

    var errorDescription: String? {
        runtimeIssue.guidanceText
    }

    private static func missingAPIKeyMessage(provider: String) -> String {
        switch provider {
        case "OpenRouter":
            return "OpenRouter is selected, but no API key is configured."
        case "Anthropic":
            return "Claude direct fallback is selected, but no direct Anthropic key is configured."
        default:
            return "\(provider) is selected, but no API key is configured."
        }
    }

    private static func missingAPIKeyNextStep(provider: String) -> String {
        switch provider {
        case "Anthropic":
            return "Add an OpenRouter API key in Settings > Cloud API Keys to use Claude through OpenRouter, then retry or switch to Ollama."
        default:
            return "Open Settings > Cloud API Keys, add the required key, then retry."
        }
    }

    private static func providerFailureMessage(provider: String, statusCode: Int, message: String?) -> String {
        let summary: String

        switch statusCode {
        case 400:
            summary = "\(provider) rejected the request"
        case 401, 403:
            summary = "\(provider) could not authenticate this request"
        case 404:
            summary = "\(provider) could not find the requested model or endpoint"
        case 408, 409:
            summary = "\(provider) could not complete this request"
        case 429:
            summary = "\(provider) is rate limiting requests"
        case 500...599:
            summary = "\(provider) is unavailable right now"
        default:
            summary = "\(provider) returned an error"
        }

        guard let detail = sanitizedProviderMessage(message) else {
            return "\(summary) (HTTP \(statusCode))."
        }

        return "\(summary) (HTTP \(statusCode)). Provider message: \(detail)"
    }

    private static func providerRecoveryStep(provider: String, statusCode: Int) -> String {
        switch statusCode {
        case 401, 403:
            if provider == "Anthropic" {
                return "Add an OpenRouter API key in Settings > Cloud API Keys to use Claude through OpenRouter, then retry."
            }
            return "Check the API key in Settings > Cloud API Keys, then retry."
        case 404:
            return "Switch to another model and retry."
        case 408, 409, 429:
            return "Wait a moment and retry, or switch to another provider/model."
        case 500...599:
            return "Retry shortly, or switch to another provider/model while the service recovers."
        default:
            return "Retry once. If it repeats, switch to another provider/model and review your provider settings."
        }
    }

    private static func sanitizedProviderMessage(_ message: String?) -> String? {
        guard let message else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(240))
    }
}
