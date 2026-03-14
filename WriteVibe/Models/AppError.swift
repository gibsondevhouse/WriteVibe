//
//  AppError.swift
//  WriteVibe
//

import Foundation

enum WriteVibeError: Error, LocalizedError {
    case network(underlying: Error)
    case apiError(provider: String, statusCode: Int, message: String?)
    case missingAPIKey(provider: String)
    case modelUnavailable(name: String)
    case generationFailed(reason: String)
    case decodingFailed(context: String)
    case exportFailed(reason: String)
    case persistenceFailed(operation: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .network(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .apiError(let provider, let statusCode, let message):
            let detail = message.map { " — \($0)" } ?? ""
            return "\(provider) API error (HTTP \(statusCode))\(detail)"
        case .missingAPIKey(let provider):
            return "No API key configured for \(provider). Add your key in Settings → Cloud API Keys."
        case .modelUnavailable(let name):
            return "Model '\(name)' is not available. Make sure it is installed and the provider is running."
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .decodingFailed(let context):
            return "Failed to decode response: \(context)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .persistenceFailed(let operation):
            return "Failed to save data during \(operation)."
        case .cancelled:
            return "Operation was cancelled."
        }
    }
}
