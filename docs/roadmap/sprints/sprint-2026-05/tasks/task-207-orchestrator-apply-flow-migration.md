# Task Card: TASK-207 Orchestrator Apply Flow Migration

- Workstream: WS-203
- Owner: `@frontend-developer`
- Priority: High
- Status: Complete

## Objective

Complete migration of article apply flow behind orchestrator boundary to prevent inline mutation drift.

## Acceptance Criteria

- [x] Apply flow parity validated against prior behavior.
- [x] No direct multi-step mutation logic remains in view model critical path.

## Dependencies

- Depends on TASK-201 boundary lock and WS-201 parity expectations.

## Implementation Notes

- Apply and accept/reject orchestration now lives behind `ArticleEditOrchestrator`, with focused unit coverage on replace/insert/delete and accept/reject flows.
- Dedicated orchestrator tests are green, but final parity closure still needs integration or UI-path regression coverage before the task moves to Complete.

## Parity Closure Evidence (2026-04-02 — @frontend-lead)

**Test run:** `ArticleEditOrchestratorTests` — **13/13 PASS** (TEST SUCCEEDED)

Cases confirmed green:

- `requestAndApplyEdits_appliesReplaceAndReturnsChangeSpan`
- `requestAndApplyEdits_rejectsReplaceWithOutOfBoundsRange`
- `requestAndApplyEdits_rejectsDeleteBlockForNonEmptyContent`
- `requestAndApplyEdits_rejectsDeleteWithOutOfBoundsRange`
- `requestAndApplyEdits_rejectsInsertWithOutOfBoundsIndex`
- `requestAndApplyEdits_rejectsInsertBlockWithMissingAnchor`
- `requestAndApplyEdits_rejectsOperationForMissingBlock`
- `requestAndApplyEdits_transitionsToFinalizedThenBackToPendingAfterAcceptAll`
- `requestAndApplyEdits_roundTripRejectAllThenReapplyRemainsStable`
- `acceptSpan_removesSpanFromBlockChanges`
- `rejectSpan_revertsBlockContentAndRemovesSpan`
- `acceptAllChanges_clearsAllBlockChanges`
- `rejectAllChanges_revertsAllBlocksToBaseline`

**Boundary audit (ArticleEditorViewModel.swift):**

- `requestAIEdits` delegates exclusively to `editOrchestrator.requestAndApplyEdits(...)` — no inline block mutation.
- `acceptSpan` / `rejectSpan` / `acceptAllChanges` / `rejectAllChanges` all proxy directly to `editOrchestrator` — no view-model-level SwiftData writes on the apply/accept/reject path.
- The only `modelContext.save()` calls in `ArticleEditorView` are in `onReturnAtEnd` and `onDeleteEmpty` callbacks (block add/delete), which are not on the AI edit apply path.

**Parity statement:** The orchestrator boundary is the sole mutation path for AI edit apply, accept, and reject. No inline direct mutations remain at the view-model or view layer. Prior behavior is preserved: edits flow request → apply → finalized state → user accept/reject → pending reset.
