//
//  ServiceContainerTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
@testable import WriteVibe

@MainActor
struct ServiceContainerTests {

    @MainActor
    private final class RecordingObservabilityService: AppleWorkflowObservabilityServicing {
        private(set) var artifacts: [AppleWorkflowRunArtifact] = []

        func recordRun(_ artifact: AppleWorkflowRunArtifact) async {
            artifacts.append(artifact)
        }
    }

    @Test func testClaudeRoutingToOpenRouterWhenGatewayKeyIsPresent() async throws {
        let container = ServiceContainer(hasSearchAPIKey: { true })

        let sonnetProvider = container.provider(for: .claudeSonnet)
        #expect(sonnetProvider is OpenRouterService)

        let gptProvider = container.provider(for: .gpt4o)
        #expect(gptProvider is OpenRouterService)

        let ollamaProvider = container.provider(for: .ollama)
        #expect(ollamaProvider is OllamaService)
    }

    @Test func testClaudeRoutingFallsBackToAnthropicWithoutGatewayKey() async throws {
        let container = ServiceContainer(hasSearchAPIKey: { false })

        let sonnetProvider = container.provider(for: .claudeSonnet)
        #expect(sonnetProvider is AnthropicService)
    }

    @Test func testAppleIntelligenceNotRoutedForChat() async throws {
        let container = ServiceContainer()
        #expect(container.route(for: .appleIntelligence, modelIdentifier: nil) == nil)

        let ollamaProvider = container.provider(for: .ollama)
        #expect(ollamaProvider is OllamaService)

        let appleProvider = container.provider(for: .appleIntelligence)
        let stream = appleProvider.stream(model: "Apple Intelligence", messages: [], systemPrompt: "")
        do {
            for try await _ in stream {
                Issue.record("Expected Apple Intelligence chat provider stream to fail immediately")
            }
            Issue.record("Expected Apple Intelligence chat provider stream to throw")
        } catch {
            #expect(true)
        }
    }

    @Test func testStructuredWorkflowRouteBlocksGenericChatEntryPoint() async throws {
        let container = ServiceContainer()
        let decision = container.evaluateAppleStructuredWorkflowRoute(for: AppleWorkflowRouteRequest(
            taskKind: .outlineSuggestion,
            entryPoint: .genericChat,
            articleID: UUID(),
            hasSelection: false,
            rolloutPhase: .internalValidation,
            featureFlagEnabled: true
        ))

        switch decision {
        case .blocked(let reason):
            #expect(reason.contains("cannot route through chat"))
        default:
            Issue.record("Expected generic chat route to be blocked")
        }
    }

    @Test func testStructuredWorkflowServiceIsWiredWithObservabilityBoundary() async throws {
        let recorder = RecordingObservabilityService()
        let container = ServiceContainer(appleWorkflowObservabilityService: recorder)
        let snapshot = AppleStructuredPlanningSnapshot(
            articleID: UUID(),
            title: "",
            topic: "",
            audience: "",
            summary: "",
            outline: "",
            purpose: "",
            style: "",
            keyTakeaway: "",
            publishingIntent: "",
            sourceLinks: "",
            targetLength: ArticleLength.medium.rawValue,
            tone: ArticleTone.informative.rawValue,
            updatedAt: Date()
        )

        let result = await container.appleStructuredWorkflowService.suggestOutline(from: snapshot)

        #expect(result.state == .validationFailed)
        #expect(recorder.artifacts.count == 1)
        #expect(recorder.artifacts.first?.taskKind == .outlineSuggestion)
    }
}
