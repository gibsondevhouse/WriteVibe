//
//  InMemoryPersistenceAdapter.swift
//  WriteVibe
//

import Foundation

/// In-memory implementation of MessagePersistenceAdapter for testing and feature flag bypass.
/// Buffers all placeholder lifecycle transitions in memory without persisting to SwiftData.
/// Useful for:
/// - Unit testing streaming logic in isolation
/// - Feature flag bypass mode (when persistence adapter is disabled)
/// - Validating adapter contract without storage dependencies
@MainActor
final class InMemoryPersistenceAdapter: MessagePersistenceAdapter {
    /// Tracks active message handles and their content
    private var activeMessages: [MessageHandle: String] = [:]
    /// Maps handle to generation context for lifecycle tracking
    private var runByHandle: [MessageHandle: GenerationRunContext] = [:]
    /// Tracks finalized handles to prevent reuse
    private var finalizedHandles: Set<MessageHandle> = []
    
    func beginAssistantMessage(run: GenerationRunContext) throws -> MessageHandle {
        let handle = MessageHandle(id: UUID())
        activeMessages[handle] = ""
        runByHandle[handle] = run
        return handle
    }

    func appendToken(_ token: String, handle: MessageHandle) throws {
        guard activeMessages[handle] != nil else {
            throw MessagePersistenceError.invalidHandle
        }
        guard !finalizedHandles.contains(handle) else {
            throw MessagePersistenceError.invalidHandle
        }
        activeMessages[handle] = (activeMessages[handle] ?? "") + token
    }

    func finalize(handle: MessageHandle, outcome: FinalizationOutcome) throws {
        guard activeMessages[handle] != nil else {
            throw MessagePersistenceError.invalidHandle
        }
        
        // Idempotent: if already finalized, no-op
        if finalizedHandles.contains(handle) {
            return
        }
        
        finalizedHandles.insert(handle)
        // Note: We keep content in activeMessages for potential inspection
        // but the handle is now marked finalized
    }
}
