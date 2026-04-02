---
name: "Refactor Hunting"
description: "Search the WriteVibe codebase for high-ROI refactor opportunities, prioritize them by payoff and risk, and document focused recommendations with clear ownership and next actions. Use when looking for structural cleanup worth doing soon."
argument-hint: "Area to inspect, constraints, or focus such as app state, services, articles, or testability"
agent: "Architect"
---
Search the WriteVibe codebase for high-ROI refactor opportunities.

Use these repository references as the source of truth:
- [WriteVibe Roadmap](../../docs/roadmap/writevibe-roadmap.md)
- [Sprint Planning Hub](../../docs/roadmap/sprints/README.md)
- [Handoff Protocol](../HANDOFF-PROTOCOL.md)

Your job is to inspect the codebase, identify the best refactor candidates, rank them by return on investment, and produce agent-ready recommendations.

## Inputs To Infer Or Use From Arguments

Extract and normalize these inputs from the user request:
- Target area or subsystem, if specified
- Refactor goal, if specified
- Constraints such as low risk, high impact, or testability focus
- Whether the output should feed a sprint/workstream immediately

If the user does not specify an area, inspect the highest-risk and highest-leverage parts of the codebase first.

## Required Behavior

1. Search the actual codebase before making recommendations.
2. Prioritize refactors that reduce complexity, improve maintainability, lower regression risk, or unlock future work.
3. Focus on high-ROI opportunities rather than stylistic cleanup.
4. Distinguish between quick wins, medium refactors, and major structural work.
5. Tie findings to concrete files, risks, and likely payoff.
6. If appropriate, create or update sprint/workstream documentation so the refactor path is ready for agents to pick up.
7. Keep all outputs agent-facing and decision-oriented.

## Evaluation Criteria

For each refactor candidate, assess:
- Why it matters now
- Scope and affected files
- Risk if left unchanged
- Estimated effort
- Expected payoff
- Best owner (`@architect`, `@frontend-lead`, `@backend-lead`, or `@qa-lead`)
- Whether it belongs in the current sprint, next sprint, or backlog

## Preferred Output Structure

Produce:
1. A prioritized shortlist of refactor opportunities
2. A quick rationale for each candidate
3. A recommended execution path for the top candidate
4. If the user asks for planning artifacts or if a sprint context exists, create or update sprint/workstream docs under `docs/roadmap/sprints/`

## Execution Sequence

1. Search the codebase for oversized files, tightly coupled modules, duplicated logic, fragile state, or weakly tested complexity.
2. Compare findings against known roadmap risks where relevant.
3. Rank the best opportunities by payoff versus effort and risk.
4. Recommend the top refactors with ownership and next steps.
5. If requested or obviously useful, write agent-facing planning docs for the strongest candidate.
6. Summarize assumptions and residual risks.

## Preferred Documentation Style

Use:
- Ranked lists
- File-specific evidence
- Clear payoff language
- Ownership and sequencing guidance

Avoid:
- Style-only cleanup suggestions
- Large unfocused laundry lists
- Refactors without clear business or maintenance value
- Recommendations detached from actual code evidence

## Example Invocations

- `/refactor-hunting inspect app state and service orchestration for the highest ROI refactor`
- `/refactor-hunting find quick-win refactors in article editing flows`
- `/refactor-hunting search the whole codebase for the best next structural cleanup and draft a workstream if justified`
