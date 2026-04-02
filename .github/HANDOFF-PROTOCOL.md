# Handoff Protocol — Agent Team Workflow

This document defines the standardized handoff process for delegating work between agents in the WriteVibe development team.

## Overview

Handoffs occur at five key junctures in the workflow:

```
CTO (Intake) → Product Manager (Requirements) → Architect (Design) → Leads (Implementation) → QA (Verification)
```

Each handoff must include:
1. **Clear context** — What problem are we solving?
2. **Scope boundaries** — What is in/out of scope?
3. **Acceptance criteria** — How will we know it's done?
4. **Dependencies** — What does the receiving agent need from previous agents?
5. **Blockers flag** — Any known risks or open questions?

---

## Handoff Template

Use this format for all inter-agent handoffs:

```markdown
## Work Order: [Feature/Bug Name]

**From:** @[delegating-agent]  
**To:** @[receiving-agent]  
**Priority:** [Critical/High/Medium/Low]  
**Due Date:** [YYYY-MM-DD]

### Context
[1-2 sentences explaining the business problem or user need]

### Scope
- ✅ **In Scope:** What this includes
- ❌ **Out of Scope:** What this explicitly does NOT include

### Acceptance Criteria (Checklist)
- [ ] Criterion 1 (testable, specific)
- [ ] Criterion 2
- [ ] Criterion 3

### Deliverables
- Document 1: `path/to/file.md`
- Document 2: `path/to/file.md`

### Dependencies
- Depends on: @[previous-agent]'s work on [deliverable]
- Needs: [specific input/data/decision]

### Known Blockers / Open Questions
- [ ] Blocker 1: [description]
- [ ] Blocker 2: [description]

### Handoff Checklist (Sending Agent)
- [ ] All acceptance criteria defined and unambiguous
- [ ] Scope explicitly bounded (no scope creep)
- [ ] Deliverables specified (exactly what to produce)
- [ ] Dependencies listed (what info is needed?)
- [ ] Blockers/questions flagged (anything unclear?)
- [ ] Previous agent's work incorporated (if applicable)

---

### Status Trail (For Tracking)
| Date | Status | Assigned To | Notes |
|------|--------|-------------|-------|
| [date] | In Progress | @[agent] | Initial handoff |
| | Blocked | @[agent] | Reason... |
| | Ready for Review | @[agent] | Deliverables complete |
| | Approved | @[qa-lead] | Ready to ship |
```

---

## Per-Agent Handoff Responsibilities

### 1. CTO → Product Manager
**When:** User brings a feature request, bug report, or goal  
**What to handoff:**

```markdown
## Work Order: [Feature Name]

**From:** @cto  
**To:** @product-manager  
**Priority:** [Critical/High/Medium/Low]

### Context
[User's stated problem or request]

### Scope
- ✅ **In Scope:** [What we ARE doing]
- ❌ **Out of Scope:** [What we ARE NOT doing]

### Open Questions for Clarification
- [ ] Question 1: [specific, actionable]
- [ ] Question 2: [specific, actionable]

### Handoff Checklist
- [ ] Scope explicitly bounded
- [ ] Any conflicting requirements from previous sprints flagged
- [ ] Delivery context provided (marketing calendar, user pain point, etc.)
```

**Product Manager's Handoff Checklist Before Delegating:**
- ✅ Requirements document written and saved to `docs/requirements/`
- ✅ User stories in standard format (As a…, I want…, so that…)
- ✅ Acceptance criteria are testable and specific
- ✅ Out-of-scope items explicitly listed
- ✅ No technical implementation details (architect owns that)
- ✅ Summary prepared for `@architect` and both lead agents

---

### 2. Product Manager → Architect
**When:** Requirements are locked and unambiguous  
**What to handoff:**

```markdown
## Work Order: Design for [Feature Name]

**From:** @product-manager  
**To:** @architect  

### Requirements Reference
- See: `docs/requirements/[feature-name].md`

### User Stories (1-3 key stories)
- As [user], I want [action] so that [outcome].
- As [user], I want [action] so that [outcome].

### Acceptance Criteria (from Product Manager)
- [ ] [specific, testable criterion]
- [ ] [specific, testable criterion]

### Design Questions for Architect
- [ ] How do we persist this data?
- [ ] What API endpoints are needed?
- [ ] How does this fit with existing services?

### Constraints
- Must work with: [existing system, service, API]
- Performance target: [if applicable]
- Security requirement: [if applicable]
```

**Architect's Handoff Checklist Before Delegating:**
- ✅ API contracts defined and saved to `docs/architecture/api-contracts/`
- ✅ Data models documented to `docs/architecture/data-models/`
- ✅ Component/service structure defined
- ✅ Trade-offs flagged for CTO review
- ✅ Frontend and backend leads can work in parallel without conflicts

---

### 3. Architect → Frontend Lead / Backend Lead
**When:** Design is locked and decisions are final  
**What to handoff:**

```markdown
## Work Order: Implement [Feature Name] — Frontend

**From:** @architect  
**To:** @frontend-lead  

### Design Reference
- API Contract: `docs/architecture/api-contracts/[feature].md`
- Data Model: `docs/architecture/data-models/[model].md`

### Frontend Tasks
- [ ] Component: [ComponentName] — [brief description]
- [ ] Hook: [useHookName] — [brief description]
- [ ] Page/Route: [/route] — [brief description]

### API Integration
- Endpoint: `POST /api/example`
- Request shape: [exact schema from contract]
- Response shape: [exact schema from contract]
- Error handling: [status codes to handle]

### Acceptance Criteria (design-derived)
- [ ] Component renders correctly in light/dark modes
- [ ] API calls match contract exactly
- [ ] Loading/error states implemented
- [ ] Accessibility requirements met

### Dependencies
- Depends on: @backend-lead implementing [endpoints]
- Frontend testing: Will be handed to @frontend-tester

### Known Risks
- [ ] Risk: [description]
- [ ] Risk: [description]
```

**Frontend/Backend Lead's Handoff Checklist Before Delegating to Developers:**
- ✅ Tasks broken down by component/endpoint (max 3-4 LOC files per task)
- ✅ Each developer task has clear acceptance criteria
- ✅ Interdependencies between frontend and backend tasks identified
- ✅ Testing strategy defined in outline for testers
- ✅ Implementation delegated to developers with clear scope

---

### 4. Leads → Developers / Testers
**When:** Implementation scope is locked  
**What to handoff:**

```markdown
## Task: Implement [ComponentName] / Endpoint

**From:** @[frontend/backend]-lead  
**To:** @[developer/tester]  

### Description
[What does this component/endpoint do?]

### Acceptance Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] [Testable criterion 3]

### Implementation Notes
- Reference design: [section in design doc]
- Use pattern: [existing pattern to follow]
- Dependencies: [what must already exist]

### Testing Plan (for testers)
- Test scenario 1: [when user does X, Y should happen]
- Test scenario 2: [edge case]
- Test scenario 3: [error case]

### Definition of Done
- [ ] Code written and locally tested
- [ ] PR opened with description referencing this task
- [ ] Code review passed (at least 1 approval)
- [ ] Passed to QA for final verification
```

**Developer/Tester's Handoff Checklist Before PR:**
- ✅ All acceptance criteria met
- ✅ No console errors or warnings
- ✅ Code follows project conventions
- ✅ Tests written and passing
- ✅ Ready for code review

---

### 5. Lead → QA Lead
**When:** Implementation complete, tests passing locally  
**What to handoff:**

```markdown
## Ready for QA: [Feature Name]

**From:** @[frontend/backend]-lead  
**To:** @qa-lead  
**PR:** [link to PR]

### What Was Built
- Brief description of feature/fix
- Components/endpoints changed: [list]

### Acceptance Criteria (from Product Manager + Architect)
- [ ] [Criterion 1 — how did we verify?]
- [ ] [Criterion 2 — how did we verify?]
- [ ] [Criterion 3 — how did we verify?]

### Testing Completed
- [x] Unit tests: X tests passing
- [x] Integration tests: X tests passing
- [x] Manual testing: [scenarios tested]

### Known Limitations / Risks
- [List any known issues or edge cases]

### Deployment Readiness
- [ ] No breaking changes
- [ ] Backward compatible
- [ ] No new dependencies added
- [ ] Performance impact: [none/minimal/describe]

### QA Sign-Off Checklist
- [ ] Requirements met (cross-check against `docs/requirements/`)
- [ ] All acceptance criteria verified
- [ ] No regressions in related features
- [ ] Cross-browser/platform testing done (if applicable)
- [ ] Performance acceptable
- [ ] Ready to ship ✅
```

---

## Escalation Protocol

If a receiving agent encounters a blocker, follow this:

1. **Flag immediately** — Don't wait. Add to the **Known Blockers** section in the work order.
2. **Provide context** — Explain why you're blocked (decision needed? missing info? dep not ready?)
3. **Suggest resolution** — Propose an either/or for CTO to decide
4. **Escalate to CTO** — If blocker impacts timeline, CTO makes final call

**Example Escalation:**
```markdown
## BLOCKER: API contract needs decision

**From:** @frontend-lead  
**To:** @cto  

### Blocker Description
API contract from @architect specifies paginated responses, but we haven't decided on page size limit or cursor format.

### Impact
Can't start frontend implementation without knowing response shape. Estimate 2-day delay if not resolved by [date].

### Options for CTO
- Option A: Use 20-item pages, cursor-based pagination (matches competitor spec)
- Option B: Use 50-item pages, offset pagination (simpler to implement)

### Recommendation
Option A — matches user expectations; worth the extra complexity.
```

---

## Handoff Status Tracking

Track all work orders in a GitHub Discussion or shared doc. Each work order should have:

```
| Feature | From → To | Status | Due | Notes |
|---------|-----------|--------|-----|-------|
| Article AI Search | CTO → PM | ✅ Complete | 4/10 | Ready for QA |
| Chat Streaming | PM → Arch | 🔄 In Progress | 4/15 | Awaiting CTO decision on buffering |
| Export PDF | Arch → FE Lead | ⏳ Blocked | 4/12 | API contract undefined |
```

---

## Best Practices

1. **Unambiguous scope** — If you can't explain it in 2 sentences, break it down more
2. **Testable criteria** — Every acceptance criterion should be verifiable in 5 minutes
3. **One handoff per agent** — Don't start next handoff until current work is done
4. **Async-friendly** — Each work order must be readable standalone (no slack threads)
5. **Quick escalation** — Flag blockers on day 1, not day 3
6. **Celebrate wins** — When a feature ships, mark it and move on

---

## Quick Reference: Workflow Diagram

```
User Request
     ↓
   CTO (Clarify scope, decide go/no-go)
     ↓
❌ OUT OF SCOPE ─→ [Archive in backlog]
✅ PROCEED
     ↓
   Product Manager (Write requirements)
     ↓
[Ambiguous?] ─→ CTO (Clarify) ─→ [Back to PM]
✅ Requirements locked
     ↓
   Architect (Design API/data/services)
     ↓
[Trade-off decision needed?] ─→ CTO (Decide) ─→ [Back to Arch]
✅ Design locked
     ↓
   Frontend Lead         Backend Lead
   (Break down tasks)    (Break down tasks)
        ↓                       ↓
   Frontend Dev          Backend Dev
   (Implement)           (Implement)
        ↓                       ↓
   Frontend Tester       Backend Tester
   (Test)                (Test)
        ↓                       ↓
⏳ HOLD (waiting for peer tests)
     ↓
   QA Lead (Final verification + sign-off)
     ↓
✅ SHIP
```
