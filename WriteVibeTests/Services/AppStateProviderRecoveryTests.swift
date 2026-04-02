//
//  AppStateProviderRecoveryTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct AppStateProviderRecoveryTests {

    private func makeAppState() throws -> (AppState, Conversation) {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let services = ServiceContainer(hasSearchAPIKey: { false })
        let appState = AppState(services: services)
        appState.bindModelContextIfNeeded(context)

        let conversation = services.conversationService.create(model: .ollama, modelIdentifier: "test-model", context: context)
        return (appState, conversation)
    }

    @Test func testOllamaSearchFailureSurfacesRuntimeIssueAndAssistantGuidance() async throws {
        let (appState, conversation) = try makeAppState()
        appState.isSearchEnabled = true

        #expect(appState.send("Find current AI news", in: conversation.id))

        for _ in 0..<200 {
            if appState.thinkingId == nil {
                break
            }
            await Task.yield()
        }

        guard let runtimeIssue = appState.runtimeIssue else {
            Issue.record("Expected a runtime recovery issue after the Ollama search failure.")
            return
        }
        #expect(runtimeIssue.title == "Search unavailable")
        #expect(runtimeIssue.message.contains("Web search is unavailable for this Ollama request"))
        #expect(runtimeIssue.nextStep.contains("Turn off Search and resend your prompt"))

        guard let updatedConversation = appState.fetchConversation(conversation.id) else {
            Issue.record("Expected the conversation to remain available after the recovery flow.")
            return
        }
        guard let lastMessage = updatedConversation.messages.last else {
            Issue.record("Expected an assistant recovery message to be appended to the conversation.")
            return
        }
        #expect(lastMessage.role == .assistant)
        #expect(lastMessage.content.contains("Web search is unavailable for this Ollama request"))
        #expect(lastMessage.content.contains("Next step:"))
        #expect(appState.isSearchFetching == false)
    }
}