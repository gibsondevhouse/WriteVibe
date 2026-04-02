# Task Card: TASK-201 Protocol Boundary Lock

- Workstream: WS-201
- Owner: `@architect`
- Priority: High
- Status: Complete

## Objective

Finalize and reconcile architecture boundary contracts for streaming/persistence and article edit orchestration against delivered implementation.

## Acceptance Criteria

- [x] Boundary contracts are documented and approved by `@backend-lead` and `@frontend-lead`.
  - [x] Documented: contract and transient model specs exist in architecture artifacts.
  - [x] Approved: backend and frontend sign-offs are recorded in sprint-2026-05 artifacts.
- [x] Feature flags are identified for rollback-safe rollout.
  - `useStreamingPersistenceAdapter`
  - `useProviderPolicyRouter`
  - `useArticleEditOrchestrator`
  - `useStrictEditValidation`

## Reconciliation Snapshot (2026-04-02)

- Streaming/persistence boundary is documented and delivered in code.
  - Architecture contract: `docs/architecture/service-contracts/v1-readiness-critical-path-contracts.md`
  - Protocol/runtime evidence: `WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift`, `WriteVibe/Services/StreamingService.swift`, `WriteVibe/Models/AppConstants.swift`
  - Contract validation evidence: `WriteVibeTests/Services/StreamingServiceContractTests.swift` and TASK-203 completion record.
- Edit orchestration boundary is documented and delivered in code.
  - Architecture contract: `docs/architecture/service-contracts/v1-readiness-critical-path-contracts.md`
  - Protocol/runtime evidence: `WriteVibe/Features/Articles/ArticleEditOrchestrator.swift`, `WriteVibe/Features/Articles/ArticleEditorViewModel.swift`
  - Unit validation evidence: `WriteVibeTests/Services/ArticleEditOrchestratorTests.swift`.
- Approval state synchronized in sprint tracking.
  - TASK-201 moved to Complete on 2026-04-02.
  - B-203 closed on 2026-04-02 after explicit backend/frontend signoff capture.

## Lead Sign-Off

- Backend Lead (`@backend-lead`) sign-off: **Approved** on 2026-04-02.
  - Rationale: Streaming/persistence boundary contract is documented in architecture artifacts, implemented on adapter-only mutation path, and validated by service contract tests (TASK-203 evidence).
- Frontend Lead (`@frontend-lead`) sign-off: **Approved** on 2026-04-02.
  - Rationale: Edit-orchestration boundary lock is acceptable because the architect contract is aligned with the implemented `ArticleEditOrchestrator` + `ArticleEditorViewModel` behavior and existing unit coverage validates the boundary path.

## Exact Missing Items Before Complete

- None in TASK-201 scope.

## Dependencies

- Requires requirements baseline from sprint-2026-05 proposal.
