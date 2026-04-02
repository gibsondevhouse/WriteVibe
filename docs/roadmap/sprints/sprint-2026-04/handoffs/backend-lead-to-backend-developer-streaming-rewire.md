# Work Order: Streaming Adapter Rewire

**From:** `@backend-lead`  
**To:** `@backend-developer`  
**Priority:** High  
**Due Date:** 2026-04-11  
**Status:** Complete and Validated (2026-04-02)

## Context

WS-101 requires moving StreamingService internals to the persistence adapter path while preserving behavior parity. TASK-101 has completed all prerequisite protocol and adapter work.

## Scope

- ✅ **In Scope:** Execute TASK-102 and prepare integration notes for tester handoff.
- ❌ **Out of Scope:** Schema changes or provider feature expansion.

## Prerequisites Completed (TASK-101)

- [x] `MessagePersistenceAdapter` protocol defined and documented
- [x] `SwiftDataMessagePersistenceAdapter` production implementation
- [x] `InMemoryPersistenceAdapter` testing implementation (for feature flag bypass)
- [x] `GenerationRunContext`, `MessageHandle`, `FinalizationOutcome` types
- [x] Protocol contract documentation: `WriteVibe/Services/Persistence/MessagePersistence.swift`
- [x] Feature flag added: `AppConstants.useStreamingPersistenceAdapter` (default: true; false remains rollback fallback)
- [x] Contract tests ready in TASK-108: `StreamingServiceContractTests.swift`

## Acceptance Criteria (Checklist)

- [x] Streaming internals use adapter path behind existing flag.
- [x] Success/cancel/error behavior remains parity-safe.
- [x] Task board and task card are updated with execution notes.

## Architecture Overview

### Current State (StreamingService.swift)

StreamingService already accepts `messagePersistenceAdapter` parameter and uses it:

```swift
func streamReply(
    provider: AIStreamingProvider,
    modelName: String,
    conversationId: UUID,
    context: ModelContext,
    ...
) async throws {
    // Create placeholder
    let runContext = GenerationRunContext(...)
    let handle = try messagePersistenceAdapter.beginAssistantMessage(run: runContext)
    
    // Append tokens in batches
    for try await token in stream {
        tokenBuffer += token
        if tokenCount >= AppConstants.tokenBatchSize {
            try messagePersistenceAdapter.appendToken(tokenBuffer, handle: handle)
            tokenBuffer = ""
        }
    }
    
    // Finalize with outcome
    try messagePersistenceAdapter.finalize(handle: handle, outcome: .succeeded)
}
```

**Key Points:**
- StreamingService already delegates all message writes to adapter
- Default adapter is SwiftDataMessagePersistenceAdapter (persists to SwiftData)
- Feature flag `AppConstants.useStreamingPersistenceAdapter` controls which adapter to use

### Your Work (TASK-102)

**Option A: Minimal Change (Recommended)**
1. Check if feature flag is already being used in StreamingService.init()
2. If not, wire feature flag to select adapter:
   ```swift
   self.messagePersistenceAdapter = (AppConstants.useStreamingPersistenceAdapter)
       ? SwiftDataMessagePersistenceAdapter(conversationService: conversationService)
       : InMemoryPersistenceAdapter()
   ```
3. Toggle flag and verify all TASK-108 tests pass with both adapters

**Option B: Full Rewire (if streaming isn't already using adapter)**
1. Identify all direct SwiftData writes in StreamingService
2. Move them behind messagePersistenceAdapter interface
3. Add feature flag selection
4. Validate parity with contract tests

**Most Likely:** Option A is needed — just wire the feature flag selection.

## Testing & Validation

### Must Pass Before Merge

- [ ] All TASK-108 contract tests pass with InMemoryPersistenceAdapter (flag: false)
- [ ] All TASK-108 contract tests pass with SwiftDataMessagePersistenceAdapter (flag: true)
- [ ] No regressions in existing StreamingService behavior
- [ ] Message lifecycle success, cancel, and error paths all verified

### Validation Approach

```bash
# Test with flag OFF (in-memory adapter)
1. Set AppConstants.useStreamingPersistenceAdapter = false
2. Run: xcodebuild test -only-testing:WriteVibeTests/StreamingServiceContractTests

# Test with flag ON (SwiftData adapter)
3. Set AppConstants.useStreamingPersistenceAdapter = true
4. Run: xcodebuild test -only-testing:WriteVibeTests/StreamingServiceContractTests

# Both should pass identically
```

## Files to Review

- [StreamingService.swift](WriteVibe/Services/StreamingService.swift) — Main service
- [MessagePersistenceAdapter.swift](WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift) — Protocol
- [SwiftDataMessagePersistenceAdapter implementation](WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift) — Lines 60+
- [InMemoryPersistenceAdapter.swift](WriteVibe/Services/Streaming/InMemoryPersistenceAdapter.swift) — For testing
- [StreamingServiceContractTests.swift](WriteVibeTests/Services/StreamingServiceContractTests.swift) — Contract validation

## Deliverables

- Task card update: `docs/roadmap/sprints/sprint-2026-04/tasks/task-102-streaming-rewire-adapter.md`
- Board update: `docs/roadmap/sprints/sprint-2026-04/03-task-board.md`
- Code: Modified StreamingService.init() with feature flag wiring (if needed)

## Dependencies

- Depends on: TASK-101 adapter contract baseline. ✅ COMPLETE
- Needs: QA criteria from WS-105 contract tests. ✅ READY (TASK-108 tests defined)
- Blocker Gate: TASK-108 must be green before you merge

## Known Blockers / Open Questions

- [x] Is StreamingService.init() already wiring the feature flag? Resolved: explicit flag-driven adapter selection is now implemented.
- [x] Do contract tests currently pass with both adapters? Resolved: focused suite passed (15/15) with flag-path coverage tests.

## Handoff Checklist (Sending Agent)

- [x] All acceptance criteria defined and unambiguous
- [x] Scope explicitly bounded (no scope creep)
- [x] Deliverables specified (exactly what to produce)
- [x] Dependencies listed (what info is needed?)
- [x] Blockers/questions flagged (anything unclear?)
- [x] Previous agent's work incorporated (TASK-101 complete)
- [x] Feature flag control ready for use
- [x] Contract tests ready for validation

---

## Status Trail (For Tracking)

- 2026-04-02 - Planned → Ready for Handoff - `@backend-lead` - TASK-101 complete; prerequisite work validated
- 2026-04-02 - Ready for Handoff - `@backend-developer` - Handoff created; TASK-102 execution authorized.
- 2026-04-02 - In Progress → Complete - `@backend-lead` - Flag-driven adapter selection landed; focused streaming lifecycle + contract suite passed (15/15).

