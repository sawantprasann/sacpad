---
story_key: 0-13-operational-health-view
epic: 0
depends_on: 0-12-politician-roster
baseline_commit: 1a6daddfc6f06898dc96476be3974f39c0df8c47
---

# Story 0.13: Platform operational health view

## Story

As a platform operator,
I want a health view of jobs, queues, and external-provider headroom,
So that I can spot a failing sync or an expired token before it becomes an outage.

## Acceptance Criteria

1. Given background jobs and external integrations exist, when the Console health view is opened, then it surfaces daily sync-job success rate, background-queue depth, and external rate-limit/token headroom (FR18).
2. It highlights failed/stale sync jobs and expired external tokens (FR18).
3. An `ops`-tier Admin sees health scoped to assigned orgs (FR18, UX-DR19).

## Tasks/Subtasks

- [x] Task 1: Health metrics (AC: 1)
  - [x] `Console::PlatformHealthController` surfacing daily sync-job success rate, queue depth, and external rate-limit/token headroom
- [x] Task 2: Problem highlighting (AC: 2)
  - [x] Highlight failed/stale sync jobs and expired external tokens in the view
- [x] Task 3: Ops-tier scoping (AC: 3)
  - [x] `ops`-tier Admin sees health scoped to assigned orgs
- [x] Task 4: Tests + verify (AC: all)
  - [x] Health view renders metrics; problem highlighting; ops-tier scoping

## Dev Notes

- **Context:** architecture §Operational health (jobs/queues/provider headroom). Brief FR18, UX-DR19.
- **Scope guard:** ONLY the read-only Console health view. The jobs/queues it reports on (Solid Queue) and the external integrations (Meta, WhatsApp/SMS, IVRS) are built in their own epics; this story presents whatever signal exists.
- **Tenancy:** health is Console-only; an `ops`-tier Admin sees it scoped to assigned orgs, consistent with Story 0.11.

## Dev Agent Record

### Debug Log

- The view is intentionally read-only and defensive about missing signal — integrations arrive in later epics, so it presents whatever metrics exist rather than assuming all providers are wired.

### Implementation Plan

`Console::PlatformHealthController#show` aggregating sync success rate / queue depth / provider headroom → health show view with failed/stale/expired highlighting → ops-tier assigned-org scoping → route → platform-health integration test.

### Completion Notes

- The Console health view surfaces daily sync-job success rate, background-queue depth, and external rate-limit/token headroom, highlighting failed/stale jobs and expired tokens.
- An `ops`-tier Admin sees health scoped to assigned orgs.

## File List

- `app/controllers/console/platform_health_controller.rb` (added)
- `app/views/console/platform_health/show.html.erb` (added)
- `config/routes.rb` (modified)
- `test/integration/console_platform_health_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.13 **backfilled from commit d8a1aaa** — read-only Console operational-health view (sync success rate, queue depth, provider headroom) with failed/stale/expired highlighting and `ops`-tier scoping. Status → review. |

## Status

review
