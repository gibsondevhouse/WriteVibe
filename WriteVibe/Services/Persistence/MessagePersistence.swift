// MessagePersistence Protocol & Adapter Architecture
// 
// This file documents the MessagePersistence adapter pattern used by StreamingService
// to decouple message lifecycle management from persistence implementation.
//
// LOCATION: WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift
//           WriteVibe/Services/Streaming/InMemoryPersistenceAdapter.swift
//
// RATIONALE: Streaming token buffering requires different persistence strategies
// depending on context (chat conversations, article drafts, etc.) and test environments.
// The adapter pattern enables StreamingService to be provider-agnostic.
//

// PROTOCOL: MessagePersistenceAdapter (@MainActor)
// 
// Three core operations:
// 
// 1. beginAssistantMessage(run:) -> MessageHandle
//    - Creates a placeholder message for streaming to populate
//    - Accepts GenerationRunContext with conversation scope and model info
//    - Returns opaque MessageHandle to track lifecycle
//    - Throws: .missingConversation, .placeholderCreationFailed
// 
// 2. appendToken(_: handle:) -> Void
//    - Buffers token string into the placeholder message
//    - Called per batch (batch size = AppConstants.tokenBatchSize = 6)
//    - Throws: .invalidHandle if handle is not active
// 
// 3. finalize(handle: outcome:) -> Void
//    - Commits or cancels the placeholder lifecycle
//    - Accepts FinalizationOutcome: succeeded | cancelled | failed(Error)
//    - IDEMPOTENT: Multiple finalize calls are safe (second and later are no-ops)
//    - Throws: .invalidHandle if handle is not recognized
// 

// IMPLEMENTATIONS:
// 
// 1. SwiftDataMessagePersistenceAdapter (PRODUCTION)
//    - Persists placeholder messages to SwiftData Conversation.messages[]
//    - Saves ModelContext on finalize
//    - Used by default in StreamingService.init()
// 
// 2. InMemoryPersistenceAdapter (TESTING / FEATURE FLAG BYPASS)
//    - Buffers messages in memory; no persistence layer
//    - Useful for: unit testing, feature flag rollback, isolated testing
//    - Used when: feature flag useStreamingPersistenceAdapter = false
// 

// LIFECYCLE CONTRACT:
// 
// Success Path:
//   beginAssistantMessage() -> active handle
//   → appendToken() [repeated] -> tokens accumulated
//   → finalize(.succeeded) -> message committed, handle released
// 
// Cancellation Path:
//   beginAssistantMessage() -> active handle
//   → appendToken() [repeated] -> partial tokens accumulated
//   → finalize(.cancelled) -> message cancelled, handle released
// 
// Error Path:
//   beginAssistantMessage() -> active handle
//   → appendToken() [repeated] -> partial tokens accumulated
//   → finalize(.failed(error)) -> message marked failed, handle released
// 
// Edge Case (Idempotent):
//   beginAssistantMessage() -> active handle
//   → appendToken() -> tokens accumulated
//   → finalize(.succeeded) -> message committed
//   → finalize(.cancelled) [or any outcome] [IDEMPOTENT, no-op]
// 

// FEATURE FLAG (TASK-102 responsibility):
// - Flag name: useStreamingPersistenceAdapter
// - Default: false (disabled for rollback safety)
// - When false: StreamingService uses InMemoryPersistenceAdapter
// - When true: StreamingService uses SwiftDataMessagePersistenceAdapter
// - Allows rollback if persistence layer has regression
// 

// TYPES:
// 
// struct GenerationRunContext
// - conversationId: UUID
// - modelName: String  
// - context: ModelContext
// Transient metadata for correlation across stream/provider/persistence boundaries
// 
// struct MessageHandle
// - id: UUID
// Opaque handle to track placeholder lifecycle; not exposed to caller
// 
// enum FinalizationOutcome
// - .succeeded
// - .cancelled
// - .failed(Error)
// Terminal state for placeholder
// 
// enum MessagePersistenceError: LocalizedError
// - .missingConversation — beginAssistantMessage failed: conversation not found
// - .placeholderCreationFailed — SwiftData insert failed
// - .invalidHandle — handle not recognized or already finalized
// - .contextSaveFailed — ModelContext.save() failed
// 
