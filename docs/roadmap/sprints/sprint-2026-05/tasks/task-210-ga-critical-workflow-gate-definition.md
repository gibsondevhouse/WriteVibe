# Task Card: TASK-210 GA-Critical Workflow Gate Definition

- Workstream: WS-204
- Owner: `@qa-lead`
- Priority: High
- Status: In Progress

## Objective

Define top-5 GA-critical workflows and enforce CI gate requirements for those flows.

## Acceptance Criteria

- [x] Workflow list approved by `@product-manager`, `@architect`, and `@qa-lead`.
- [x] CI gate rule is documented and active.

## Dependencies

- Requires lead alignment on launch-critical path scope.

## Execution Checkpoints

- 2026-04-03 EOD: publish proposed top-5 workflow list with rationale and owners.
- 2026-04-04 EOD: secure approval from `@product-manager`, `@architect`, and `@qa-lead`.
- 2026-04-05 EOD: enforce CI gate rule and publish first gate run evidence.

## Proposed Top-5 GA-Critical Workflow Package

Draft published: 2026-04-02

| Workflow | Rationale | Primary Owner |
| --- | --- | --- |
| Chat send to streamed reply persistence | Core GA value path. A user prompt must produce a visible assistant reply with placeholder creation, token updates, and finalized persistence without data loss or orphaned state. | `@backend-lead` |
| In-flight response cancel/retry/finalize recovery | Launch trust depends on users being able to stop or retry generation without duplicate messages, stuck thinking state, or inconsistent conversation history. | `@backend-lead` |
| Provider failure, fallback, and recovery messaging | GA cannot ship with opaque provider failure states. Anthropic, OpenRouter, and Ollama routing failures must degrade into explicit recovery guidance rather than silent or generic failure. | `@backend-lead` |
| Article rewrite request to diff review rendering | AI edit confidence is launch-critical for article workflows. Rewrite requests must produce an inspectable diff view so users can understand proposed changes before applying them. | `@frontend-lead` |
| Article diff accept/apply persistence integrity | Approval to apply a rewrite must preserve document structure and persist the accepted result through the orchestrator boundary without corruption or dropped edits. | `@frontend-lead` |

## Approval Status

Target approval date: 2026-04-04 EOD

- `@product-manager`: Signed off. Name: GitHub Copilot (`@product-manager`). Date: 2026-04-02. Notes: Product approves the package after the 2026-04-02 ownership correction resolved the WS-201 accountability gap for the two stream lifecycle workflows. The top-5 set now cleanly covers the highest-trust GA paths without mixing lead accountability and tester validation roles.
- `@architect`: Signed off. Name: GitHub Copilot (`@architect`). Date: 2026-04-02. Notes: Ownership correction resolves the prior architecture objection by assigning the two WS-201 stream lifecycle workflows to `@backend-lead`, which restores clear implementation accountability for the streaming and persistence boundary without changing the frozen top-5 scope.
- `@qa-lead`: Signed off. Name: GitHub Copilot (`@qa-lead`). Date: 2026-04-02. Notes: QA approves this top-5 package as small enough for reliable CI enforcement and broad enough to cover the highest-trust GA paths across streamed chat persistence, cancel/retry recovery, provider failure guidance, and article diff/apply integrity. CI enforcement evidence and remaining lead approvals are still required before task closeout.

## Evidence Required For Closeout

- Approved workflow list link in sprint handoff trail.
- CI configuration/automation evidence and passing run snapshot.
- QA signoff note confirming merge-block behavior for critical workflow failures.

## Active Gate Rule (Effective 2026-04-02)

- Merge gate policy: the frozen top-5 workflow test pack must pass before promoting related tasks from Review to Complete.
- Enforcement command:
  `xcodebuild -project WriteVibe.xcodeproj -scheme WriteVibe -destination 'platform=macOS' test -only-testing:WriteVibeTests/StreamingServiceContractTests -only-testing:WriteVibeTests/StreamingServiceTests -only-testing:WriteVibeTests/ProviderRecoveryTests -only-testing:WriteVibeTests/ArticleEditOrchestratorTests -only-testing:WriteVibeTests/ChatRewriteDiffSupportTests`
- Failure behavior: any failing suite in this pack blocks workflow-gated task closure and requires owner triage before re-run.

## First Enforcement Evidence

- 2026-04-02: first critical workflow gate run executed using the active command.
- Result: `** TEST SUCCEEDED **`.
- Scope covered: streamed reply persistence lifecycle, cancel/retry/finalize parity, provider fallback/recovery mapping, rewrite diff rendering, and article apply integrity behaviors.
