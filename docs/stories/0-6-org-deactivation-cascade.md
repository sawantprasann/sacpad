---
story_key: 0-6-org-deactivation-cascade
epic: 0
depends_on: 0-5-org-onboarding-wizard
baseline_commit: b2431273d76591c284aa4b9a20e7777162ddafdb
---

# Story 0.6: Organization deactivation cascade

## Story

As a platform operator,
I want deactivating an organization to immediately cut off all its users,
So that an ended campaign's data becomes inaccessible in one action.

## Acceptance Criteria

1. Given an active organization, when an Admin sets it inactive, then every user under it, at every depth, immediately fails authentication (`active_for_authentication?` also checks `organization.active?`) (FR9).
2. Every Pundit scope's base query filters to active organizations, so a live session sees no data after deactivation (FR9).
3. Reactivating restores access without per-user changes.

## Tasks/Subtasks

- [x] Task 1: Deactivate/reactivate actions (AC: 1, 3)
  - [x] `Organization#deactivate!`/`#reactivate!` toggling the `active` flag; Console action on the org
- [x] Task 2: Auth cutoff (AC: 1)
  - [x] `User#active_for_authentication?` also checks `organization.active?` so every user, at every depth, fails auth when the org is inactive
- [x] Task 3: Scope filtering (AC: 2)
  - [x] Pundit scope base queries filter to active organizations so a live session sees no data after deactivation
- [x] Task 4: Tests + verify (AC: all)
  - [x] Deep user fails auth when org inactive; reactivation restores access with no per-user change

## Dev Notes

- **Context:** architecture §Org lifecycle + §Auth. Brief FR9.
- **Scope guard:** ONLY the deactivation/reactivation cascade and its auth/scope enforcement. Org creation + health list is Story 0.5 (same commit). Soft-delete of records is Story 0.10 (distinct from org deactivation).
- **Tenancy:** deactivation is a single flag flip whose effect cascades through `active_for_authentication?` and the Pundit scopes — no per-user mutation, so reactivation is symmetric.

## Dev Agent Record

### Debug Log

- The cascade is intentionally implemented at the auth + scope layer (not by touching each user) so that one flag flip immediately cuts off the whole subtree and reactivation restores it with no per-user changes.

### Implementation Plan

`Organization#deactivate!`/`#reactivate!` → extend `User#active_for_authentication?` to also require `organization.active?` → ensure Pundit scope base queries filter to active orgs → deactivation/reactivation cascade tests.

### Completion Notes

- Setting an org inactive makes every user under it (any depth) fail authentication via `active_for_authentication?`, and live sessions see no data because scopes filter to active orgs.
- Reactivation restores access with no per-user changes — the whole behavior hangs off the single `organization.active?` flag.

## File List

- `app/models/organization.rb` (modified — `deactivate!`/`reactivate!`)
- `app/models/user.rb` (modified — `active_for_authentication?` org check)
- `app/controllers/console/organizations_controller.rb` (modified — activate/deactivate action)
- `test/integration/console_organizations_test.rb` (modified — cascade tests)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.6 **backfilled from commit 67696cd** (shared with 0.5) — organization deactivation cascade: `deactivate!`/`reactivate!`, `User#active_for_authentication?` org-active check, and active-org scope filtering. Status → review. |

## Status

review
