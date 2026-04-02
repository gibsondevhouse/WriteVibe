# WriteVibe Workspace Instructions

These instructions apply to all coding tasks in this repository.

## Operating Mode

- Prefer implementation over planning when a request is actionable.
- Keep edits minimal and scoped; avoid unrelated refactors.
- Preserve existing architecture and naming unless the task requires change.
- Use links to existing docs instead of duplicating large guidance blocks.

## Build and Test

Use the WriteVibe Xcode project and scheme on macOS.

- Build:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' build`
- Full test run:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test`
- Focused critical-path gate pack:
  - `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceContractTests -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/ProviderRecoveryTests -only-testing:WriteVibeTests/ArticleEditOrchestratorTests -only-testing:WriteVibeTests/ChatRewriteDiffSupportTests`

If a task changes only one subsystem, run targeted tests first and then run full tests when practical.

## Architecture and Boundaries

Follow existing boundaries and avoid bypassing them.

- App shell and state orchestration:
  - `WriteVibe/State/AppState.swift`
  - `WriteVibe/Services/ConversationGenerationManager.swift`
- Dependency composition and provider routing:
  - `WriteVibe/Services/ServiceContainer.swift`
- Streaming and persistence boundary:
  - `WriteVibe/Services/StreamingService.swift`
  - `WriteVibe/Services/Streaming/MessagePersistenceAdapter.swift`
- Article edit orchestration boundary:
  - `WriteVibe/Features/Articles/ArticleEditOrchestrator.swift`

Reference docs:
- `README.md`
- `docs/architecture/v1-readiness-sprint-contract-2026-04-post.md`
- `docs/architecture/next-sprint-risk-reduction-plan-2026-04.md`

## Project Conventions

- Use protocol-driven services and dependency injection via ServiceContainer.
- Keep UI logic in SwiftUI/view-model layers and service logic in Services.
- Preserve feature-flag behavior in `WriteVibe/Models/AppConstants.swift` when touching critical paths.
- For tests that touch app state or UI-coupled behavior, respect `@MainActor` patterns used in existing test files.

## Documentation and Handoffs

- Use the sprint-control docs under `docs/roadmap/sprints/` as the source of truth for status, blockers, and QA gates.
- Use standardized handoff structure from:
  - `.github/HANDOFF-QUICK-START.md`
  - `.github/HANDOFF-PROTOCOL.md`

When updating sprint docs, synchronize the following together if statuses change:
- sprint task board,
- risks/blockers,
- QA gates,
- workstream/index summaries.

## Git Gotchas

- `docs/` is ignored in `.gitignore`.
- If intentionally committing sprint/docs updates, stage them explicitly with force add:
  - `git add -f docs/...`
- Do not use destructive git commands unless explicitly requested.

## Agent Sections

Use these routing expectations when working in team-mode flows.

### CTO

- Owns final delivery decisions, blocker policy, and readiness sign-off.
- Keeps WS-205 blocker operations current and resolves escalation conflicts.
- Reference: `.github/agents/cto.agent.md`

### Product Manager

- Produces requirements, user stories, acceptance criteria, and scope boundaries.
- Does not prescribe implementation details.
- Reference: `.github/agents/product-manager.agent.md`

### Architect

- Owns service contracts, data model boundaries, and technical decision records.
- Ensures frontend/backend teams can execute in parallel safely.
- Reference: `.github/agents/architect.agent.md`

### Backend Lead

- Owns WS-201/WS-202 delivery, backend delegation, and backend readiness evidence.
- Coordinates backend developer + backend tester handoffs.
- Reference: `.github/agents/backend-lead.agent.md`

### Backend Developer

- Implements service/model/provider logic within established boundaries.
- Follows layering conventions and existing naming/style.
- Reference: `.github/agents/backend-developer.agent.md`

### Backend Tester

- Validates service and persistence behavior via unit/integration tests.
- Reports evidence and coverage to Backend Lead; does not modify production code.
- Reference: `.github/agents/backend-tester.agent.md`

### Frontend Lead

- Owns WS-203 delivery and frontend architecture decisions.
- Delegates to frontend developer/tester and closes frontend handoff loops.
- Reference: `.github/agents/frontend-lead.agent.md`

### Frontend Developer

- Implements SwiftUI views/workflows and view-model integrations.
- Preserves existing UX patterns unless requirement explicitly changes them.
- Reference: `.github/agents/frontend-developer.agent.md`

### Frontend Tester

- Validates unit/UI behavior for frontend flows and review-state tasks.
- Reports readiness evidence to Frontend Lead and QA Lead.
- Reference: `.github/agents/frontend-tester.agent.md`

### QA Lead

- Owns quality gates, gate-pack enforcement, blocker verification, and final QA recommendations.
- Keeps `05-qa-gates.md` aligned with objective run evidence.
- Reference: `.github/agents/qa-lead.agent.md`

## Current Sprint Links (Implementation-Ready)

- `docs/roadmap/sprints/sprint-2026-05/00-charter.md`
- `docs/roadmap/sprints/sprint-2026-05/02-agent-workstreams.md`
- `docs/roadmap/sprints/sprint-2026-05/03-task-board.md`
- `docs/roadmap/sprints/sprint-2026-05/04-risks-and-blockers.md`
- `docs/roadmap/sprints/sprint-2026-05/05-qa-gates.md`

Use these as the operational source of truth for implementation sequencing and blocker state.
