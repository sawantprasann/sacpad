---
story_key: 0-4-reference-data-catalog-editor
epic: 0
depends_on: 0-3-admin-console
baseline_commit: 313becece2dc86e0641f43eab97b04d42a6ac27e
---

# Story 0.4: Shared reference data — geography, parties, and the catalog editor

## Story

As a platform operator,
I want to manage global geography and party reference data from the Console,
So that organizations can be tied to constituencies and themed by party.

## Acceptance Criteria

1. Given an authenticated `full`-tier Admin, when reference data is managed in the Console, then `State → Loksabha → Assembly → Village → Booth` reference tables exist and are editable (FR15).
2. A `parties` table (name, abbreviation, color, logo via Active Storage) is editable (FR15).
3. A reusable Console "catalog editor" pattern is established — later reused for ticket categories, PR categories, media platforms, and outdoor-ad types in their module epics (FR15).
4. Reference data is global (shared across every organization) and editable only by `Admin` (never org-facing).

## Tasks/Subtasks

- [x] Task 1: Geography hierarchy models + migration (AC: 1)
  - [x] `State → Loksabha → Assembly → Village → Booth` tables with parent FKs; models with `belongs_to`/`has_many`
  - [x] None are tenant-scoped (global reference data, no `organization_id`)
- [x] Task 2: Party model + migration (AC: 2)
  - [x] `parties` table: name, abbreviation, color, Active Storage logo attachment
- [x] Task 3: Reusable catalog-editor pattern (AC: 3)
  - [x] `Console::ReferenceController` base with index/new/create/edit/update CRUD, driven by a per-resource config; thin subclass controllers (`StatesController`, `LoksabhasController`, `AssembliesController`, `VillagesController`, `BoothsController`, `PartiesController`)
  - [x] Shared `reference/index|new|edit|_form` views
- [x] Task 4: Routes + Console nav (AC: 1, 4)
  - [x] Reference routes nested under the `console` namespace, behind `authenticate_admin!`
- [x] Task 5: Tests + verify (AC: all)
  - [x] Geography association test; console reference CRUD integration test; global (non-tenant) scoping confirmed

## Dev Notes

- **Context:** architecture §Shared reference data + §Project Structure (`Console::` namespace). Brief FR15.
- **Scope guard:** ONLY global geography + parties + the reusable catalog editor. Constituency *link* to an org is Story 0.5; party *theming* of org chrome is Story 0.14; module-specific catalogs (ticket/PR categories, media platforms, ad types) are their own epics.
- **Tenancy:** geography and parties are global reference tables — no `organization_id`, never run through `acts_as_tenant`. Editable only by Admin from the Console.

## Dev Agent Record

### Debug Log

- The catalog editor was built as a config-driven base controller (`Console::ReferenceController`) so module epics can mint a new catalog by subclassing + supplying a resource config, rather than copy-pasting CRUD.

### Implementation Plan

Geography migration (State→Loksabha→Assembly→Village→Booth) + Party migration (with Active Storage logo) → models with associations → `Console::ReferenceController` base + thin per-resource subclasses → shared reference views (index/new/edit/_form) → console routes → geography + console-reference tests.

### Completion Notes

- Five-level geography hierarchy and a `parties` table (abbreviation, color, logo) are editable from the Console by a `full`-tier Admin only.
- The reusable catalog-editor pattern (`Console::ReferenceController` + shared views) is the template later epics reuse for their own catalogs.
- All reference data is global and non-tenant-scoped; no org-facing edit surface exists.

## File List

- `app/models/state.rb`, `app/models/loksabha.rb`, `app/models/assembly.rb`, `app/models/village.rb`, `app/models/booth.rb` (added)
- `app/models/party.rb` (added — Active Storage logo)
- `app/controllers/console/reference_controller.rb` (added — reusable catalog editor base)
- `app/controllers/console/states_controller.rb`, `loksabhas_controller.rb`, `assemblies_controller.rb`, `villages_controller.rb`, `booths_controller.rb`, `parties_controller.rb` (added — thin subclasses)
- `app/views/console/reference/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb` (added)
- `db/migrate/20261004140000_create_geography_and_parties.rb` (added)
- `db/schema.rb`, `config/routes.rb` (modified)
- `test/models/geography_test.rb`, `test/integration/console_reference_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.4 **backfilled from commit 64a3eca** — global geography hierarchy + parties + reusable `Console::ReferenceController` catalog editor. Status → review. |

## Status

review
