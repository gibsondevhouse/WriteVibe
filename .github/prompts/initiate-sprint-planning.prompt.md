---
name: "Initiate Sprint Planning"
description: "Create or update an agent-focused sprint planning pack in docs/roadmap/sprints, including charter, workstreams, task board, risks, QA gates, and handoff-ready documentation. Use when starting a new sprint or re-baselining an existing one."
argument-hint: "Sprint name, date range, focus, goals, and any seed workstreams"
agent: "CTO"
---
Create or update an agent-focused sprint planning pack for WriteVibe.

Use these repository references as the source of truth:
- [Sprint Planning Hub](../../docs/roadmap/sprints/README.md)
- [Sprint Index](../../docs/roadmap/sprints/_indexes/sprint-index.md)
- [Active Workstreams](../../docs/roadmap/sprints/_indexes/active-workstreams.md)
- [Handoff Protocol](../HANDOFF-PROTOCOL.md)

Your job is to initialize or refresh the correct sprint documentation under `docs/roadmap/sprints/`.

## Inputs To Infer Or Use From Arguments

Extract and normalize these inputs from the user request:
- Sprint folder name in the form `sprint-YYYY-MM`
- Date range
- Sprint owner
- Strategic focus
- Success outcomes
- Seed workstreams
- Known risks or blockers

If one or more values are missing, make reasonable defaults based on the current date and the user request. Do not stop for clarification unless the sprint identity itself is impossible to infer.

## Required Behavior

1. Work only inside `docs/roadmap/sprints/` unless the user explicitly asks for broader roadmap edits.
2. Keep all documentation agent-facing, not developer-facing.
3. Follow the sprint structure defined in [Sprint Planning Hub](../../docs/roadmap/sprints/README.md).
4. Use the handoff expectations from [Handoff Protocol](../HANDOFF-PROTOCOL.md) when creating handoff-ready docs.
5. Reuse existing sprint templates under `docs/roadmap/sprints/_templates/` when present.
6. If the sprint folder already exists, update it instead of recreating it.
7. Keep naming consistent for sprint folders, workstreams, tasks, and handoff files.
8. Prefer concise planning language focused on ownership, delegation, validation, and closure.

## Files To Create Or Update

Ensure the sprint pack includes these files where applicable:
- `00-charter.md`
- `01-goals-and-outcomes.md`
- `02-agent-workstreams.md`
- `03-task-board.md`
- `04-risks-and-blockers.md`
- `05-qa-gates.md`
- `06-retro.md`
- `handoffs/`
- `workstreams/`
- `tasks/`

Also update supporting index files when needed:
- `docs/roadmap/sprints/_indexes/sprint-index.md`
- `docs/roadmap/sprints/_indexes/active-workstreams.md`

## Output Standard

Generate documentation that is:
- Agent-operational
- Handoff-ready
- Status-driven
- Explicit about ownership
- Easy to audit from sprint charter through QA gate

## Execution Sequence

1. Inspect the existing sprint docs and templates.
2. Determine whether this is a new sprint or an update to an existing sprint.
3. Create or update the sprint folder and required documents.
4. Add or update at least one workstream doc, one task card, and one handoff doc when the sprint is new.
5. Update sprint indexes so the new sprint is discoverable.
6. Verify wording stays agent-centric throughout.
7. Summarize what was created or changed and note any assumptions.

## Preferred Documentation Style

Use:
- Short sections
- Checklists for acceptance and QA gates
- Tables for indexes and task boards
- Direct ownership labels with agent names

Avoid:
- Developer playbook language
- Detailed implementation guidance
- Broad product strategy outside the current sprint
- Unowned tasks or vague acceptance criteria

## Example Invocations

- `/initiate-sprint-planning sprint-2026-05 focused on article editor hardening and QA readiness`
- `/initiate-sprint-planning create next sprint for AI writing analysis improvements, May 1 to May 31`
- `/initiate-sprint-planning refresh sprint-2026-04 with new workstream for export flow validation`
