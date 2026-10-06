---
story_key: 0-10-soft-delete-audit-framework
epic: 0
depends_on: 0-9-hierarchical-user-management
baseline_commit: 67696cd16554a51b46449a06b79e0a2f34f991d3
---

# Story 0.10: Soft-delete and the two-tier audit framework

## Story

As a platform operator,
I want every change tracked and every delete recoverable,
So that the platform has an accountable, auditable history.

## Acceptance Criteria

1. Given the domain models, when records are changed or deleted, then `discard` provides soft-delete (`discarded_at`/`discarded_by_id`); no domain data is hard-deleted; delete is Org Admin/Admin only and asks for confirmation stating recoverability (FR-soft-delete, NFR19, UX-DR8).
2. A Tier-1 `paper_trail` pattern using **custom per-model version classes** is established (FR52).
3. A Tier-2 lightweight status-change log pattern is established (FR53).
4. A cross-table append-only `ActivityLog` (actor + type, action, record type/id, organization, timestamp) records "who did what, where" (FR54).
5. Every create/update is timestamped and attributable (NFR27).

## Tasks/Subtasks

- [x] Task 1: Soft-delete concern (AC: 1)
  - [x] `SoftDeletable` using `discard` (`discarded_at`/`discarded_by_id`); no hard delete of domain data; delete gated to Org Admin/Admin with recoverability confirmation
- [x] Task 2: Tier-1 versioning pattern (AC: 2)
  - [x] `FullyVersioned` concern establishing the `paper_trail` custom per-model version-class pattern
- [x] Task 3: Tier-2 status-change log pattern (AC: 3)
  - [x] Lightweight status-change log pattern established for module reuse
- [x] Task 4: Cross-table ActivityLog (AC: 4, 5)
  - [x] Append-only `ActivityLog` (actor + type, action, record type/id, organization, timestamp); `Auditable` controller concern to record actions
- [x] Task 5: Tests + verify (AC: all)
  - [x] Soft-delete recoverability; versioning; ActivityLog append + attribution

## Dev Notes

- **Context:** architecture §Audit & soft-delete (two-tier audit; append-only ActivityLog). Brief FR52/FR53/FR54, NFR19/NFR27, UX-DR8.
- **Scope guard:** ONLY the reusable soft-delete + audit *framework* (concerns, ActivityLog, patterns). The Admin cross-org access logging + banner + audit-log *view* is Story 0.11; `Voter`'s concrete Tier-1 version class is Story 0.15.
- **Tenancy:** `ActivityLog` carries `organization` so cross-table "who did what, where" is attributable per tenant; it is append-only.

## Dev Agent Record

### Debug Log

- Soft-delete, Tier-1 versioning, and auditing are shipped as reusable concerns (`SoftDeletable`, `FullyVersioned`, `Auditable`) + the `ActivityLog` model so every later module opts in uniformly.
- `ActivityLog` is append-only and records actor (polymorphic Admin/User), action, record type/id, organization, and timestamp.

### Implementation Plan

`create_activity_logs` migration → `ActivityLog` model → `SoftDeletable` (discard) + `FullyVersioned` (paper_trail pattern) concerns → `Auditable` controller concern wired into `ApplicationController` + `Console::BaseController` → audit-framework tests.

### Completion Notes

- Soft-delete via `discard` with recoverability confirmation; no domain data is hard-deleted; delete is Org Admin/Admin only.
- Tier-1 (custom per-model version classes) and Tier-2 (status-change log) patterns are established, plus an append-only cross-table `ActivityLog` for "who did what, where", with every create/update timestamped and attributable.

## File List

- `app/models/activity_log.rb` (added)
- `app/models/concerns/soft_deletable.rb`, `app/models/concerns/fully_versioned.rb` (added)
- `app/controllers/concerns/auditable.rb` (added)
- `app/controllers/application_controller.rb`, `app/controllers/console/base_controller.rb` (modified — include Auditable)
- `db/migrate/20261004140700_create_activity_logs.rb` (added)
- `db/schema.rb` (modified)
- `test/models/audit_framework_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.10 **backfilled from commit 564d98e** — `discard` soft-delete, Tier-1/Tier-2 audit patterns, and an append-only `ActivityLog` with an `Auditable` controller concern. Status → review. |

## Status

review
