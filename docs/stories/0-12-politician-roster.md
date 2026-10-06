---
story_key: 0-12-politician-roster
epic: 0
depends_on: 0-11-cross-org-access-banner
baseline_commit: e2aaeae7628c206c84064312145f1faeec4cdc81
---

# Story 0.12: Per-organization Politician roster

## Story

As a platform operator,
I want to manage each organization's own candidate and tracked opponents,
So that downstream modules can reference a named Politician.

## Acceptance Criteria

1. Given an organization exists, when an Admin manages its roster from the Console, then a `politicians` table (org-scoped: name, nullable `party_id`, `is_own_politician`, photo, soft-delete columns) exists (FR16).
2. A partial-unique index enforces exactly one `is_own_politician: true` per organization, whose name stays in sync with `Organization.name` via callback (FR16).
3. The roster is org-scoped (not global) and Admin-managed only (not org-facing) (FR16).

## Tasks/Subtasks

- [x] Task 1: Politicians table + migration (AC: 1)
  - [x] `politicians`: org-scoped, name, nullable `party_id`, `is_own_politician`, photo (Active Storage), soft-delete columns
- [x] Task 2: One-own-politician invariant (AC: 2)
  - [x] Partial-unique index for exactly one `is_own_politician: true` per org; callback keeps the own politician's name in sync with `Organization.name`
- [x] Task 3: Console roster management (AC: 3)
  - [x] `Console::PoliticiansController` CRUD, org-scoped, Admin-only (no org-facing surface)
- [x] Task 4: Tests + verify (AC: all)
  - [x] Org scoping; one-own-politician enforcement; name sync; Admin-only access

## Dev Notes

- **Context:** architecture §Politician roster. Brief FR16.
- **Scope guard:** ONLY the org-scoped Politician roster, managed from the Console. Downstream modules merely *reference* a Politician; those references are built in their own epics.
- **Tenancy:** `politicians` is org-scoped (not global reference data like Story 0.4 parties); managed by Admin only, with no org-facing UI.

## Dev Agent Record

### Debug Log

- A partial-unique index (`where is_own_politician`) enforces exactly one own politician per org at the DB level; a callback keeps that record's name in sync with `Organization.name`.
- `party_id` is nullable so opponents without a tracked party, and Independent candidates, are representable.

### Implementation Plan

`create_politicians` migration (org-scoped + partial-unique index + soft-delete columns) → `Politician` model (soft-delete, own-politician invariant + name-sync callback) + `Organization` association → `Console::PoliticiansController` CRUD + views → routes → model + console roster tests.

### Completion Notes

- Each org has its own `politicians` roster (own candidate + tracked opponents), with exactly one `is_own_politician` enforced by a partial-unique index and kept name-synced to the org.
- The roster is org-scoped and Admin-managed only — there is no org-facing roster UI.

## File List

- `app/models/politician.rb` (added)
- `app/models/organization.rb` (modified — politicians association + own-politician wiring)
- `app/controllers/console/politicians_controller.rb` (added)
- `app/views/console/politicians/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb` (added)
- `db/migrate/20261004140800_create_politicians.rb` (added)
- `db/schema.rb`, `config/routes.rb` (modified)
- `test/models/politician_test.rb`, `test/integration/console_politicians_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.12 **backfilled from commit 1a6dadd** — org-scoped `Politician` roster with a one-own-politician partial-unique index + name-sync callback, managed Console-only. Status → review. |

## Status

review
