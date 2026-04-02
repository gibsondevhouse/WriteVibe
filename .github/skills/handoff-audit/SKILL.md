---
name: handoff-audit
description: 'Audit agent planning and sprint artifacts for handoff quality, missing ownership, vague acceptance criteria, and weak blocker tracking. Use for validating that agent docs are ready for delegation and execution.'
argument-hint: 'Target sprint, workstream, or planning folder to audit'
user-invocable: true
---

# Handoff Audit

## When to Use

- Validate sprint or workstream docs before execution begins
- Check whether agent handoff records are complete and usable
- Find missing owners, weak acceptance criteria, or blocker gaps
- Prepare documentation for QA or CTO review

## References

- [Handoff Protocol](../../HANDOFF-PROTOCOL.md)
- [Sprint Planning Hub](../../../docs/roadmap/sprints/README.md)

## Procedure

1. Inspect the target sprint folder, workstream docs, task cards, and handoff records.
2. Verify that each handoff includes:
   - clear context
   - bounded scope
   - acceptance criteria
   - dependencies
   - blockers or open questions
   - explicit sender and receiver ownership
3. Check that task and workstream docs align with current status and owners.
4. Flag missing or ambiguous artifacts.
5. Where appropriate, update docs to make them handoff-ready.

## Audit Checklist

- Every workstream has an owner
- Every task has a status and next owner
- Every blocker has an escalation owner
- QA gate criteria are present where needed
- Documentation is agent-facing, not developer-facing

## Output Standard

- Findings ordered by severity
- Specific missing artifacts or fields
- Concrete fixes or updates applied when straightforward

## Avoid

- Generic feedback without file-specific context
- Leaving obvious handoff gaps unaddressed
