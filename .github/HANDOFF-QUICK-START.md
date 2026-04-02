# Handoff Quick Start Guide

This is a quick reference for how to handoff work between agents. For detailed procedures, see [HANDOFF-PROTOCOL.md](HANDOFF-PROTOCOL.md).

---

## The Pipeline

```
User Request
    ↓
@cto — Clarify scope
    ↓
@product-manager — Write requirements (docs/requirements/)
    ↓
@architect — Design system (docs/architecture/)
    ↓
@frontend-lead ←→ @backend-lead (parallel work)
    ↓
@frontend-developer / @backend-developer
    ↓
@frontend-tester / @backend-tester
    ↓
@qa-lead — Final sign-off
    ↓
✅ Ready to ship
```

---

## Work Order Template (Copy-Paste)

Use this template for ALL handoffs:

```markdown
## Work Order: [Feature/Bug Name]

**From:** @[your-agent]  
**To:** @[receiving-agent]  
**Priority:** [Critical/High/Medium/Low]  
**Due Date:** [YYYY-MM-DD]

### Context
[1-2 sentences explaining the business problem]

### Scope
- ✅ **In Scope:** [What this includes]
- ❌ **Out of Scope:** [What this does NOT include]

### Acceptance Criteria
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

### Handoff Checklist
- [ ] Scope explicitly bounded (no ambiguity)
- [ ] Deliverables specified (exactly what to produce)
- [ ] Dependencies listed (what info is needed?)
- [ ] Blockers/questions flagged (anything unclear?)
- [ ] Previous agent's work incorporated (if applicable)
```

---

## Agent Handoff Paths

### 1️⃣ CTO → Product Manager

**What:** Feature request, bug report, or goal  
**Checklist:**
- [ ] Request is clearly summarized
- [ ] Scope is roughly bounded
- [ ] Timeline is clear

**Example:**
```markdown
## Work Order: Search Conversations

**From:** @cto  
**To:** @product-manager  
**Priority:** High  
**Due Date:** 2026-04-10

### Context
Users can't find old conversations easily. We need search functionality to help them locate specific chats.

### Scope
- ✅ Search by conversation title
- ✅ Search by message content (first 100 chars preview)
- ❌ Search by AI model type (out of scope for MVP)

### Open Questions
- [ ] Should search be case-sensitive?
- [ ] Do we need full-text search or simple substring matching?
```

---

### 2️⃣ Product Manager → Architect

**What:** Locked requirements  
**Checklist:**
- [ ] Requirements saved to `docs/requirements/[feature].md`
- [ ] User stories written
- [ ] Acceptance criteria are testable
- [ ] No technical implementation details

**Example:**
```markdown
## Work Order: Design Search Feature

**From:** @product-manager  
**To:** @architect  

### Requirements Reference
See: `docs/requirements/search-conversations.md`

### Key User Stories
- As a user, I want to search conversations by title so I can find old chats quickly.
- As a user, I want to see a preview of message content so I can verify I found the right chat.

### Design Questions
- [ ] Should we index the database for full-text search?
- [ ] What's the max message preview length?
- [ ] How do we handle pagination of search results?

### Constraints
- Must work with existing SQLite database
- Performance target: <500ms for typical searches
```

---

### 3️⃣ Architect → Frontend Lead + Backend Lead

**What:** API contracts + data models  
**Checklist:**
- [ ] API contracts saved to `docs/architecture/api-contracts/`
- [ ] Data models saved to `docs/architecture/data-models/`
- [ ] Component/endpoint structure defined
- [ ] Trade-offs documented

**Example (Frontend):**
```markdown
## Work Order: Implement Search UI

**From:** @architect  
**To:** @frontend-lead  

### Design Reference
- API Contract: `docs/architecture/api-contracts/search.md`
- Component Structure: SearchBar (input) + SearchResults (list)

### Frontend Tasks
- [ ] SearchBar component — text input with debounce
- [ ] SearchResults component — paginated result list
- [ ] useSearch hook — manages API calls and state

### Acceptance Criteria
- [ ] Search input debounces at 300ms
- [ ] Results appear after 500ms max
- [ ] Pagination works on both mobile and desktop
- [ ] Accessibility: searchable via keyboard

### Dependencies
- Depends on: @backend-lead implementing GET /api/search endpoint
```

---

### 4️⃣ Lead → Developer / Tester

**What:** Scoped implementation tasks  
**Checklist:**
- [ ] Task scope is clear and unambiguous
- [ ] Implementation reference provided
- [ ] Dependencies identified

**Example (Developer):**
```markdown
## Task: Implement SearchBar Component

**From:** @frontend-lead  
**To:** @frontend-developer  

### Description
Implement a controlled text input component that debounces search queries at 300ms and calls the search API.

### Acceptance Criteria
- [ ] Component accepts `value` and `onChange` props
- [ ] Debounces input at 300ms using useCallback
- [ ] Calls `searchConversations(query)` after debounce
- [ ] Shows loading spinner while fetching
- [ ] Shows error message if request fails
- [ ] Unit tests with >80% coverage

### Implementation Reference
- Design: `docs/architecture/api-contracts/search.md`
- Use pattern: similar to FilterBar component in `src/components/features/FilterBar.tsx`

### Definition of Done
- [ ] `npm run build` passes
- [ ] `npx tsc --noEmit` passes
- [ ] Tests written and passing
- [ ] PR ready for review
```

---

### 5️⃣ Developer → Tester

**What:** Completed implementation  
**Checklist:**
- [ ] All tests pass locally
- [ ] No console errors
- [ ] Code review passed

**Example (Tester):**
```markdown
## Task: Test SearchBar Component

**From:** @frontend-developer  
**To:** @frontend-tester  

### What Was Built
SearchBar component with debounced input and error handling.

### Test Scenarios
- [ ] Component renders with placeholder text
- [ ] Input debounces at 300ms (not on every keystroke)
- [ ] API call fires after debounce
- [ ] Loading state shows spinner
- [ ] Error state displays error message
- [ ] Keyboard navigation works (Tab, Enter, Escape)

### Definition of Done
- [ ] All scenarios pass
- [ ] >80% code coverage
- [ ] No accessibility violations
- [ ] Ready for QA sign-off
```

---

### 6️⃣ Lead → QA Lead

**What:** All tests passing, ready for final verification  
**Checklist:**
- [ ] Unit tests >80% coverage
- [ ] Integration tests passing
- [ ] No console errors or warnings
- [ ] Lint checks passing

**Example (QA):**
```markdown
## Ready for QA: Search Feature

**From:** @frontend-lead / @backend-lead  
**To:** @qa-lead  
**PR:** https://github.com/.../pull/123

### What Was Built
- SearchBar component (frontend)
- GET /api/search endpoint (backend)
- Full integration with existing chat system

### Acceptance Criteria from Product Manager
- [ ] Users can search conversations by title ✅
- [ ] Search results show message previews ✅
- [ ] Results paginate correctly ✅

### Testing Completed
- [x] Unit tests: 15/15 passing (92% coverage)
- [x] Integration tests: 8/8 passing
- [x] Manual testing: Happy path + error cases verified
- [x] No console errors
- [x] Lint checks passing ✅

### QA Sign-Off
- [ ] All requirements met
- [ ] No regressions
- [ ] Performance acceptable
- [ ] Ready to ship ✅
```

---

## Red Flags — What NOT to Do

❌ **Vague scope** — "Build the article feature" (too big, not testable)  
✅ **Clear scope** — "Add ArticleBlock component for rendering paragraph-type content with bold/italic formatting"

❌ **Missing deliverables** — "Requirements will be decided during implementation"  
✅ **Defined deliverables** — "Deliverables: docs/requirements/search.md + Figma design link"

❌ **Ambiguous acceptance criteria** — "Make it fast"  
✅ **Testable criteria** — "API responds in <500ms for <1000 results"

❌ **Hidden dependencies** — "Assuming frontend is done by Thursday"  
✅ **Listed dependencies** — "Depends on: @backend-lead implementing /search endpoint by April 8"

---

## Escalation

If you hit a **blocker**, follow this:

1. **Flag immediately** — Don't wait; update the work order
2. **Provide context** — Why are you blocked?
3. **Suggest options** — Give CTO either/or choices
4. **Escalate** — Message @cto directly if it impacts timeline

**Example:**
```markdown
## BLOCKER: Database schema decision needed

**From:** @backend-lead  
**To:** @cto  

### Why Blocked
API contract specifies paginated search results. We haven't decided on pagination strategy (offset vs. cursor).

### Impact
Can't start backend implementation. Estimate 2-day delay if decision pushed back.

### Your Options
- **Option A:** Offset-based pagination (simpler, standard)
- **Option B:** Cursor-based pagination (scales better for large result sets)

### My Recommendation
Option B — better for production scale, aligns with our database strategy.
```

---

## Status Tracking

Keep a simple table to track all active work:

| Feature | From → To | Status | Due | Notes |
|---------|-----------|--------|-----|-------|
| Search | PM → Arch | ✅ Complete | 4/8 | Ready for leads |
| Article Editor | Arch → FE Lead | 🔄 In Progress | 4/15 | Design locked, dev started |
| Export PDF | FE Dev → Tester | ⏳ Blocked | 4/12 | Waiting for API response schema |
| Auth Refactor | BE Dev → Tester | 🔄 In Progress | 4/20 | All tests passing, QA pending |

---

## Questions?

- **For detailed procedures:** See [HANDOFF-PROTOCOL.md](HANDOFF-PROTOCOL.md)
- **For agent responsibilities:** See individual `.github/agents/*.agent.md` files
- **For blockers or unclear scope:** Escalate to @cto immediately
