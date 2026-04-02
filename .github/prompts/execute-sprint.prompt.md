---
name: "Execute Sprint"
description: "Drive execution of an existing agent-focused sprint in docs/roadmap/sprints by updating workstreams, task status, handoffs, risks, and QA gates. Use when advancing a sprint from planning into active delivery."
argument-hint: "Sprint name and the workstreams, tasks, or outcomes to advance"
agent: "CTO"
---
Execute an existing agent-focused sprint for WriteVibe.

Use these repository references as the source of truth:
- [Sprint Planning Hub](../../docs/roadmap/sprints/README.md)
- [Sprint Index](../../docs/roadmap/sprints/_indexes/sprint-index.md)
- [Active Workstreams](../../docs/roadmap/sprints/_indexes/active-workstreams.md)
- [Handoff Protocol](../HANDOFF-PROTOCOL.md)

Your job is to advance the correct sprint documentation under `docs/roadmap/sprints/` so agents have a current, actionable execution path.

## Inputs To Infer Or Use From Arguments

Extract and normalize these inputs from the user request:
- Sprint folder name in the form `sprint-YYYY-MM`
- Workstreams or tasks to advance
- New statuses, ownership changes, or blockers
- New handoffs that must be recorded
- QA or validation progress

If some details are missing, infer the minimum necessary from the current sprint docs and the user request. Do not stop for clarification unless the target sprint cannot be identified.

## Required Behavior

1. Work primarily inside the target sprint folder and sprint indexes.
2. Keep all updates agent-facing, status-driven, and handoff-ready.
3. Update existing docs instead of duplicating them.
4. Preserve the sprint folder structure defined in [Sprint Planning Hub](../../docs/roadmap/sprints/README.md).
5. Apply the handoff rules in [Handoff Protocol](../HANDOFF-PROTOCOL.md) when updating or creating handoff records.
6. Keep ownership explicit for every workstream, task, blocker, and QA gate.
7. If execution changes the active sprint picture, update `sprint-index.md` and `active-workstreams.md`.

## Files To Review And Update

Review and update the relevant sprint artifacts:
- `02-agent-workstreams.md`
- `03-task-board.md`
- `04-risks-and-blockers.md`
- `05-qa-gates.md`
- `handoffs/`
- `workstreams/`
- `tasks/`

Update supporting indexes when status changed materially:
- `docs/roadmap/sprints/_indexes/sprint-index.md`
- `docs/roadmap/sprints/_indexes/active-workstreams.md`

## Output Standard

Generate updates that are:
- Actionable for agents right now
- Explicit about next owners and next moves
- Consistent with existing sprint naming and status values
- Easy to audit without extra verbal context

## Execution Sequence

1. Inspect the target sprint folder and identify stale or missing execution artifacts.
2. Determine which workstreams and tasks should move forward based on the user request.
3. Update task statuses, owners, risks, blockers, and QA progress.
4. Create or refresh handoff docs when work changes owners.
5. Update workstream docs if scope, acceptance criteria, or dependencies changed.
6. Update the sprint indexes if active status changed.
7. Summarize what advanced, what remains blocked, and any assumptions made.

## Preferred Documentation Style

Use:
- Tables for task boards and indexes
- Checklists for gates and acceptance criteria
- Short sections with explicit ownership
- Status language such as Planned, In Progress, Blocked, Review, Complete

Avoid:
- Developer implementation playbook language
- Unowned tasks
- Vague blockers without escalation owner
- Broad roadmap rewriting outside the active sprint

## Example Invocations

- `/execute-sprint advance sprint-2026-04 with WS-002 now in progress and add QA handoff`
- `/execute-sprint update sprint-2026-04 after architect completed contract review and qa found one blocker`
- `/execute-sprint move TASK-003 to review and record backend-lead to qa-lead handoff for sprint-2026-04`
