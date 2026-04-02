# Workstream: WS-201 Critical-Path Reliability Closure

## Header

- Workstream ID: WS-201
- Sprint: sprint-2026-05
- Title: Critical-path reliability closure
- Owner: `@backend-lead`
- Status: In Progress

## Problem Statement

Streaming and persistence reliability remains the highest-impact source of v1 instability and user trust loss.

## Scope

- In scope:
  - Complete protocolized boundaries for streaming and persistence mutation paths.
  - Validate cancellation, retry, interruption, and finalize parity.
  - Remove direct stream-to-model mutation paths outside the persistence adapter.
- Out of scope:
  - Net-new generation features.
  - Non-critical architecture refactors.

## Deliverables

- Protocol and boundary lock record in architecture artifacts.
- Reliability parity evidence for success/cancel/error/retry paths.
- Status updates in task board and QA gate checklist.

## Boundary-Lock Reconciliation (2026-04-02)

- Streaming/persistence boundary:
  - State: Documented + implemented; backend lead sign-off recorded.
  - Evidence: `docs/architecture/service-contracts/v1-readiness-critical-path-contracts.md`, `WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift`, `WriteVibe/Services/StreamingService.swift`, `WriteVibeTests/Services/StreamingServiceContractTests.swift`.
- Edit orchestration boundary:
  - State: Documented + implemented; frontend lead sign-off recorded.
  - Evidence: `docs/architecture/service-contracts/v1-readiness-critical-path-contracts.md`, `WriteVibe/Features/Articles/ArticleEditOrchestrator.swift`, `WriteVibe/Features/Articles/ArticleEditorViewModel.swift`, `WriteVibeTests/Services/ArticleEditOrchestratorTests.swift`.
- Rollback flags are already documented for both boundaries in architecture artifacts.
- Tracking alignment: TASK-201 marked Complete and blocker B-203 closed after explicit backend/frontend lead sign-off capture.

## Agent Ownership

- Product: `@product-manager`
- Architecture: `@architect`
- Frontend: `@frontend-lead`
- Backend: `@backend-lead`
- QA: `@qa-lead`

## Acceptance Criteria

- [x] Protocol boundaries are documented and accepted by `@architect` and `@backend-lead`.
  - [x] Documented in current architecture contract artifacts.
  - [x] Backend lead acceptance explicitly recorded in sprint artifacts.
  - [x] Frontend lead acceptance for edit-orchestration boundary explicitly recorded in sprint artifacts.
- [x] Contract tests pass for stream lifecycle parity.
- [ ] No unresolved P0 reliability defect remains in streaming/persistence scope.

## Dependencies and Risks

- Dependencies: TASK-201 architecture boundary lock, TASK-210 QA workflow freeze.
- Risks: R-201 lifecycle regressions during rewiring.
- Open blocker linkage: B-203 is closed; remaining WS-201 caution is B-204 monitoring until CI-level confirmation checkpoint.

## Linked Tasks

- task-201
- task-202
- task-203
