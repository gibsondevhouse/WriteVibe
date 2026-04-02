//
//  AppStateProviderRecoveryTests.swift
//  WriteVibeTests
//

import Testing
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct AppStateProviderRecoveryTests {
    @Test func testLocalSearchUnavailableRecoveryGuidanceRemainsActionable() {
        let runtimeIssue = WriteVibeError.localSearchUnavailable(
            reason: "no OpenRouter API key is configured"
        ).runtimeIssue

        #expect(runtimeIssue.title == "Search unavailable")
        #expect(runtimeIssue.message.contains("Web search is unavailable for this Ollama request"))
        #expect(runtimeIssue.nextStep.contains("Turn off Search and resend your prompt"))
    }
}