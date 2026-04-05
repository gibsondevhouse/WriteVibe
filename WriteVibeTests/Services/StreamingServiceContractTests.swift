//
//  StreamingServiceContractTests.swift
//  WriteVibeTests
//
//  Contract Tests: MessagePersistenceAdapter placeholder lifecycle
//  Matrix:
//  - Placeholder create → update → finalize (success path)
//  - Placeholder create → cancel → retry (interruption path)
//  - Placeholder create → finalize → cancel (edge case: cancel after completion)
//

import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@Suite(.serialized)
@MainActor
struct StreamingServiceContractTests {

    // MARK: - Mock Persistence Adapter

    /// Records all placeholder lifecycle transitions for contract verification
    final class ContractRecordingAdapter: MessagePersistenceAdapter {
        struct Transition {
            let event: String
            let handleId: UUID
            let timestamp: Date
            let details: String
        }

        var transitions: [Transition] = []
        var activeHandles: Set<MessageHandle> = []
        var finalizedHandles: Set<MessageHandle> = []
        var tokenBuffer: [MessageHandle: String] = [:]

        func beginAssistantMessage(run: GenerationRunContext) throws -> MessageHandle {
            let handle = MessageHandle(id: UUID())
            activeHandles.insert(handle)
            transitions.append(Transition(
                event: "create",
                handleId: handle.id,
                timestamp: Date(),
                details: "Created placeholder for model: \(run.modelName)"
            ))
            return handle
        }

        func appendToken(_ token: String, handle: MessageHandle) throws {
            guard activeHandles.contains(handle) else {
                throw MessagePersistenceError.invalidHandle
            }
            guard !finalizedHandles.contains(handle) else {
                throw MessagePersistenceError.invalidHandle
            }

            tokenBuffer[handle, default: ""] += token
            transitions.append(Transition(
                event: "update",
                handleId: handle.id,
                timestamp: Date(),
                details: "Appended token, total length: \(tokenBuffer[handle]?.count ?? 0)"
            ))
        }

        func finalize(handle: MessageHandle, outcome: FinalizationOutcome) throws {
            guard activeHandles.contains(handle) else {
                throw MessagePersistenceError.invalidHandle
            }

            // Idempotent: if already finalized, no-op
            if finalizedHandles.contains(handle) {
                transitions.append(Transition(
                    event: "finalize_idempotent",
                    handleId: handle.id,
                    timestamp: Date(),
                    details: "Finalize called but handle already finalized (no-op)"
                ))
                return
            }

            finalizedHandles.insert(handle)
            let outcomeString = outcomeDescription(outcome)
            transitions.append(Transition(
                event: "finalize",
                handleId: handle.id,
                timestamp: Date(),
                details: "Finalized with outcome: \(outcomeString)"
            ))
        }

        // MARK: - Helpers

        func getTransitionsForHandle(_ handle: MessageHandle) -> [Transition] {
            transitions.filter { $0.handleId == handle.id }
        }

        func getFinalizedOutcomes() -> [String] {
            transitions
                .filter { $0.event == "finalize" }
                .map { $0.details }
        }

        func getTokenCountForHandle(_ handle: MessageHandle) -> Int {
            tokenBuffer[handle]?.count ?? 0
        }

        private func outcomeDescription(_ outcome: FinalizationOutcome) -> String {
            switch outcome {
            case .succeeded:
                return "succeeded"
            case .cancelled:
                return "cancelled"
            case .failed(let error):
                return "failed(\(error.localizedDescription))"
            }
        }
    }

    // MARK: - Test Setup

    private func makeAdapter() -> ContractRecordingAdapter {
        ContractRecordingAdapter()
    }

    // MARK: - Test Matrix

    // SCENARIO 1: Success Path — Create → Update → Finalize
    @Test func testPlaceholderSuccessPath_CreateUpdateFinalize() throws {
        let adapter = makeAdapter()
        let schema = Schema([Conversation.self, Message.self, Article.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Create placeholder
        let handle = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "test-model-1",
                context: context
            )
        )

        // Verify handle is created and active
        #expect(adapter.activeHandles.contains(handle))
        #expect(!adapter.finalizedHandles.contains(handle))

        // Update with tokens
        try adapter.appendToken("Hello ", handle: handle)
        try adapter.appendToken("world", handle: handle)

        // Verify tokens accumulated
        #expect(adapter.getTokenCountForHandle(handle) == 11)

        // Finalize with success
        try adapter.finalize(handle: handle, outcome: .succeeded)

        // Verify finalization state
        #expect(adapter.finalizedHandles.contains(handle))

        // Verify transition sequence
        let handleTransitions = adapter.getTransitionsForHandle(handle)
        #expect(handleTransitions.count == 4) // create, update, update, finalize
        #expect(handleTransitions[0].event == "create")
        #expect(handleTransitions[1].event == "update")
        #expect(handleTransitions[2].event == "update")
        #expect(handleTransitions[3].event == "finalize")
        #expect(handleTransitions[3].details.contains("succeeded"))
    }

    // SCENARIO 2: Interruption Path — Create → Cancel → Retry (new handle)
    @Test func testPlaceholderInterruptionPath_CreateCancelRetry() throws {
        let adapter = makeAdapter()
        let schema = Schema([Conversation.self, Message.self, Article.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // First placeholder attempt
        let handle1 = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "test-model-2",
                context: context
            )
        )

        // Partial tokens before cancellation
        try adapter.appendToken("Incomplete ", handle: handle1)
        try adapter.appendToken("response", handle: handle1)

        // Verify partial state
        #expect(adapter.getTokenCountForHandle(handle1) == 19)

        // Cancel this placeholder
        try adapter.finalize(handle: handle1, outcome: .cancelled)
        #expect(adapter.finalizedHandles.contains(handle1))

        // Retry: create new placeholder for same conversation
        let handle2 = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "test-model-2",
                context: context
            )
        )

        // New handle is different from cancelled one
        #expect(handle2.id != handle1.id)
        #expect(adapter.activeHandles.contains(handle2))
        #expect(!adapter.finalizedHandles.contains(handle2))

        // Succeed with retry
        try adapter.appendToken("Complete response", handle: handle2)
        try adapter.finalize(handle: handle2, outcome: .succeeded)

        // Verify both handles coexist with different outcomes
        let transitions1 = adapter.getTransitionsForHandle(handle1)
        let transitions2 = adapter.getTransitionsForHandle(handle2)

        #expect(transitions1.last?.details.contains("cancelled") ?? false)
        #expect(transitions2.last?.details.contains("succeeded") ?? false)
    }

    // SCENARIO 3: Edge Case — Create → Finalize → Cancel (idempotent)
    @Test func testPlaceholderEdgeCase_FinalizeIdempotent() throws {
        let adapter = makeAdapter()
        let schema = Schema([Conversation.self, Message.self, Article.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Create placeholder
        let handle = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "test-model-3",
                context: context
            )
        )

        // Add some tokens
        try adapter.appendToken("Response", handle: handle)

        // First finalize: success
        try adapter.finalize(handle: handle, outcome: .succeeded)
        #expect(adapter.finalizedHandles.contains(handle))

        // Second finalize attempt: should be idempotent (no-op)
        try adapter.finalize(handle: handle, outcome: .cancelled)

        // Verify transitions show idempotent behavior
        let transitions = adapter.getTransitionsForHandle(handle)
        #expect(transitions.last?.event == "finalize_idempotent")

        // Verify only one actual finalization recorded
        let finalizeTransitions = transitions.filter { $0.event == "finalize" }
        #expect(finalizeTransitions.count == 1)
        #expect(finalizeTransitions[0].details.contains("succeeded"))
    }

    // MARK: - Contract Validation Tests

    /// Verify that once a handle is finalized, further token appends are rejected
    @Test func testContractViolation_AppendAfterFinalize() async throws {
        let adapter = makeAdapter()
        let schema = Schema([Conversation.self, Message.self, Article.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let handle = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "test-model-violation-1",
                context: context
            )
        )

        try adapter.finalize(handle: handle, outcome: .succeeded)

        // Attempt to append after finalization should throw
        #expect(throws: MessagePersistenceError.self) {
            try adapter.appendToken("Late token", handle: handle)
        }
    }

    /// Verify that invalid handles are rejected
    @Test func testContractViolation_InvalidHandle() async throws {
        let adapter = makeAdapter()
        let invalidHandle = MessageHandle(id: UUID())

        // Attempt operations with non-existent handle
        #expect(throws: MessagePersistenceError.self) {
            try adapter.appendToken("Token", handle: invalidHandle)
        }

        #expect(throws: MessagePersistenceError.self) {
            try adapter.finalize(handle: invalidHandle, outcome: .succeeded)
        }
    }

    /// Verify concurrent handles maintain independent state
    @Test func testConcurrentHandles_IndependentLifecycles() throws {
        let adapter = makeAdapter()
        let schema = Schema([Conversation.self, Message.self, Article.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        // Create two concurrent placeholders
        let handle1 = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "model-A",
                context: context
            )
        )

        let handle2 = try adapter.beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: UUID(),
                modelName: "model-B",
                context: context
            )
        )

        // Interleave operations
        try adapter.appendToken("H1-", handle: handle1)
        try adapter.appendToken("H2-", handle: handle2)
        try adapter.appendToken("part1", handle: handle1)
        try adapter.appendToken("part1", handle: handle2)

        // Verify independent state
        #expect(adapter.getTokenCountForHandle(handle1) == 8)  // "H1-part1"
        #expect(adapter.getTokenCountForHandle(handle2) == 8)  // "H2-part1"

        // Finalize independently
        try adapter.finalize(handle: handle1, outcome: .succeeded)
        try adapter.finalize(handle: handle2, outcome: .cancelled)

        #expect(adapter.finalizedHandles.contains(handle1))
        #expect(adapter.finalizedHandles.contains(handle2))

        // Verify outcomes recorded separately
        let outcomes = adapter.getFinalizedOutcomes()
        #expect(outcomes.count == 2)
        #expect(outcomes.contains { $0.contains("succeeded") })
        #expect(outcomes.contains { $0.contains("cancelled") })
    }
}
