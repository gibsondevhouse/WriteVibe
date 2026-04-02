//
//  ProviderRecoveryTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
@testable import WriteVibe

@MainActor
struct ProviderRecoveryTests {

    @Test func testClaudeRouteFallsBackToAnthropicWithoutOpenRouterKey() async throws {
        let container = ServiceContainer(hasSearchAPIKey: { false })

        let route = try #require(container.route(for: .claudeSonnet, modelIdentifier: nil))

        #expect(route.provider is AnthropicService)
        #expect(route.modelName == "claude-sonnet-4-6")
    }

    @Test func testClaudeRouteUsesOpenRouterWhenKeyPresent() async throws {
        let container = ServiceContainer(hasSearchAPIKey: { true })

        let route = try #require(container.route(for: .claudeSonnet, modelIdentifier: nil))

        #expect(route.provider is OpenRouterService)
        #expect(route.modelName == "anthropic/claude-3-7-sonnet")
    }

    @Test func testAnthropicRequestUsesPublishedStableVersionHeader() throws {
        let request = try AnthropicService.makeRequest(
            apiKey: "test-key",
            model: "claude-sonnet-4-6",
            messages: [["role": "user", "content": "Hello"]],
            systemPrompt: "You are helpful."
        )

        #expect(request.value(forHTTPHeaderField: "anthropic-version") == AppConstants.anthropicAPIVersion)
        #expect(AppConstants.anthropicAPIVersion == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "test-key")
    }

    @Test func testAnthropicErrorMapperExtractsProviderMessageFromSSEBody() {
        let mapped = AnthropicService.mapAPIError(
            statusCode: 401,
            body: "data: {\"type\":\"error\",\"error\":{\"type\":\"authentication_error\",\"message\":\"invalid x-api-key\"}}"
        )

        guard case .apiError(let provider, let statusCode, let message) = mapped else {
            Issue.record("Expected mapped Anthropic API error.")
            return
        }
        #expect(provider == "Anthropic")
        #expect(statusCode == 401)
        #expect(message == "invalid x-api-key")
    }

    @Test func testAnthropicErrorMapperUsesStatusFallbackWhenBodyMissing() {
        let mapped = AnthropicService.mapAPIError(statusCode: 429, body: "")

        guard case .apiError(_, let statusCode, let message) = mapped else {
            Issue.record("Expected mapped Anthropic API error.")
            return
        }
        #expect(statusCode == 429)
        #expect(message == "Anthropic rate limited this request.")
    }

    @Test func testOpenRouterAuthenticationFailureIncludesSettingsGuidance() {
        let issue = WriteVibeError.apiError(
            provider: "OpenRouter",
            statusCode: 401,
            message: "Invalid API key"
        ).runtimeIssue

        #expect(issue.title == "OpenRouter request failed")
        #expect(issue.message.contains("could not authenticate this request"))
        #expect(issue.nextStep.contains("Settings > Cloud API Keys"))
    }

    @Test func testAnthropicFallbackAuthenticationFailurePointsToOpenRouterRecovery() {
        let issue = WriteVibeError.apiError(
            provider: "Anthropic",
            statusCode: 401,
            message: "invalid x-api-key"
        ).runtimeIssue

        #expect(issue.title == "Anthropic request failed")
        #expect(issue.message.contains("could not authenticate this request"))
        #expect(issue.nextStep.contains("use Claude through OpenRouter"))
    }
}