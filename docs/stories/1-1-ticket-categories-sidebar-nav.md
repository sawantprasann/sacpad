---
story_key: 1-1-ticket-categories-sidebar-nav
epic: 1
depends_on: 0-4-reference-data-catalog-editor
baseline_commit: 50ba0158eb45fcf23780503fc9126c9be26fd7f0
---

# Story 1.1: Ticket categories catalog and sidebar navigation

Status: review

## Story

As a platform operator,
I want to manage the Kitchen Cabinet ticket categories as shared reference data,
So that every organization sees a consistent, extensible category list without a deploy.

## Acceptance Criteria

1. Given the Console catalog-editor pattern (Story 0.4), when categories are seeded and managed, then a `ticket_categories` table (`name`, `slug`, `active`, `display_order`) is seeded with the 12 categories including "Other" and is Admin-editable (FR19, FR15).
2. Categories render as the Kitchen Cabinet left-sidebar submenu, driving a filter over the center list (FR19, UX-DR2).
3. Adding a category makes it appear with no deploy, and org-scoped tickets are unaffected.

**The 12 seeded categories (in display order, per project_brief §6.1):**
Health · Road & Transport · Water · MSEB/Electricity (power) · Student · Police Station · Farmers · Events & Camps · Personal Help · Personal Connect · Functions – Weddings/Birthdays · **Other** (catch-all, always last).

## Tasks / Subtasks

- [x] Task 1: `TicketCategory` model + migration (AC: 1)
  - [x] Migration `ticket_categories`: `name` (not null), `slug` (not null, unique index), `active` (boolean, default true, not null), `display_order` (integer, not null, indexed). Global reference data — **no `organization_id`**, does **not** include `OrganizationScoped`.
  - [x] Model `app/models/ticket_category.rb` → **top-level `TicketCategory`** (deviation from architecture's `kitchen_cabinet/` namespacing — see Completion Notes for rationale). `validates :name, :display_order, presence: true` + `slug` uniqueness; auto-derive `slug` from `name` via `before_validation` when blank; `scope :active, -> { where(active: true).order(:display_order) }`.
- [x] Task 2: Seed the 12 categories idempotently (AC: 1, 3)
  - [x] `TicketCategory.seed_defaults!` (mirrors `Role.seed_system_roles!`) seeds the 12 with explicit `display_order` 1..12 and "Other" last, via `find_or_create_by!(slug:)`; called from `db/seeds.rb`. Verified idempotent + "Other" lands last.
- [x] Task 3: Console catalog editor via the reusable pattern (AC: 1)
  - [x] `app/controllers/console/ticket_categories_controller.rb` subclasses `Console::ReferenceController` (`managed_model = TicketCategory`, `managed_fields = %i[name slug active display_order]`, `managed_title = "Ticket Category"`).
  - [x] Route `resources :ticket_categories` added inside `namespace :console`, alongside the other catalogs.
  - [x] Extended `app/views/console/reference/_form.html.erb` to switch on `columns_hash[field].type` → checkbox for `:boolean`, number input for `:integer`, text/select otherwise. Verified geography/parties catalogs still render (all use text/`_id` fields only).
- [x] Task 4: Kitchen Cabinet sidebar submenu + filter wiring (AC: 2, 3)
  - [x] `app/views/ui/_sidebar.html.erb`: replaced the static "Kitchen Cabinet … soon" item with an Alpine-expandable submenu over `TicketCategory.active`, each linking to `kitchen_cabinet_tickets_path(category: slug)`; other modules kept as "soon".
  - [x] KC nav entry gated on `current_user.role.can_access?("kitchen_cabinet")` (nav visibility).
  - [x] Stub `KitchenCabinet::TicketsController#index` (route `namespace :kitchen_cabinet { resources :tickets, only: :index }`) reads `params[:category]`, renders the themed empty-state placeholder, and **enforces** KC access in a `before_action` (not UI-only). Real scoped list = Story 1.3; `Ticket` model = Story 1.2.
- [x] Task 5: Tests + verify (AC: all)
  - [x] Model test (`test/models/ticket_category_test.rb`): not-tenant-scoped, validations, slug derivation, `active` scope ordering, `seed_defaults!` 12 + idempotent + "Other" last.
  - [x] Console integration test (`test/integration/console_ticket_categories_test.rb`): admin-auth required, create (with slug/active/display_order), toggle-inactive, appears in index.
  - [x] Nav test (`test/integration/kitchen_cabinet_nav_test.rb`): permitted user sees submenu with active categories only; no-access user sees no KC entry and is redirected from the module URL; stub honors `?category=`.
  - [x] `bin/rails test` → 82 runs / 309 assertions / 0 failures; `bin/rubocop` → 108 files, 0 offenses.

## Dev Notes

- **What this story is:** the catalog + navigation scaffolding for Epic 1. It is the *first consumer* of the Story 0.4 reusable catalog editor (`Console::ReferenceController` + `console/reference/*` shared views) and the Story 0.14 shared chrome/sidebar. Treat it as "prove the pattern extends cleanly to a KC-owned catalog."
- **Global vs. org-scoped — do not confuse:** `TicketCategory` is a **shared global catalog** (Admin-managed, one list across every org), exactly like `Party` and `Role`. The `Ticket` records filed under each category (Story 1.2) are fully org-scoped. Adding/removing a category must have zero effect on any org's data (AC 3).
- **Reuse, don't reinvent:**
  - Catalog CRUD → subclass `Console::ReferenceController` (do **not** hand-roll a new controller). See `app/controllers/console/states_controller.rb:1` for the exact subclass shape.
  - Console is the **only** place categories are managed — there is no org-facing category editor (same discipline as `Role`/`Party`). The Console wears the steel skin and `authenticate_admin!`; do not add category management to the org side.
  - Sidebar lives in `app/views/ui/_sidebar.html.erb` (org-side, party-themed). The Console has its own `_console_sidebar.html.erb` — the category *editor* link belongs there is **not** required by this story; categories are edited from the standard Console catalog index at `/console/ticket_categories`.
- **UX discipline (DESIGN.md / UX-DR):** the sidebar submenu follows the TailAdmin `.menu-item` component classes already used in `_sidebar.html.erb`; active-category highlight uses the existing `menu-item-active` / `menu-item-inactive` pattern. 44px touch targets (UX-DR14). Empty-category state shows a CTA (UX-DR14) — the real "create ticket" CTA is 1.2, so 1.1's empty state can be a simple "No tickets in {category} yet" placeholder.

### Project Structure Notes

- Model: `app/models/kitchen_cabinet/ticket_category.rb` (namespaced `KitchenCabinet::` per architecture §Project Structure, line 274). If Zeitwerk autoloading of a namespaced global model fights the `Console::ReferenceController` `managed_model` assignment, the fallback is a top-level `TicketCategory` (matching how `Party`/`State` are top-level) — but prefer the architecture's namespacing and only deviate with a noted rationale.
- Console controller: `app/controllers/console/ticket_categories_controller.rb` (architecture line 265).
- Route: inside `namespace :console` in `config/routes.rb` (architecture line 337), next to `resources :parties` / geography.
- KC org-side namespace: `namespace :kitchen_cabinet` at the clean root (architecture line 348) — 1.1 only adds `resources :tickets, only: :index` as the filter target stub.

### References

- [Source: docs/epics.md#Story-1.1] — AC (BDD), FR19/FR15, UX-DR2.
- [Source: docs/project_brief.md §6.1] — the 12 category names + `TicketCategory` shape (`id, name, slug, active, display_order`) + "shared catalog, org-scoped tickets" rule.
- [Source: docs/architecture.md#Project-Structure] (lines 265, 274, 302) and #Routes (lines 337, 348).
- [Source: app/controllers/console/reference_controller.rb] — reusable catalog base (the `_form` type-inference note).
- [Source: app/controllers/console/states_controller.rb] — subclass template.
- [Source: app/views/ui/_sidebar.html.erb] — current module placeholder to replace; `.menu-item` classes; `can_create_users?` gating precedent.
- [Source: docs/stories/0-4-reference-data-catalog-editor.md] and [0-14-shared-chrome-export-dashboard.md] — upstream patterns this story consumes.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails db:migrate` → `ticket_categories` created cleanly.
- `bin/rails test` → 82 runs, 309 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rubocop` → 108 files, 0 offenses.
- Seed sanity (`TicketCategory.seed_defaults!`): count=12, last=Other (display_order=12), `TicketCategory.table_name == "ticket_categories"`.

### Completion Notes List

- **Deliberate deviation — model kept top-level `TicketCategory`, not `KitchenCabinet::TicketCategory`.** Rationale: every other global reference-data model in this codebase (`Party`, `Role`, `State`, geography) is top-level, and the `Console::ReferenceController` catalog pattern is built around top-level reference models; namespacing only this one would be inconsistent for *reference data* and risks Rails namespaced-table-name ambiguity. The architecture's `kitchen_cabinet/` grouping is honoured for the org-scoped *domain* controllers — the `KitchenCabinet::TicketsController` stub lives there.
- Reused the Story 0.4 editor exactly: `Console::TicketCategoriesController < Console::ReferenceController` (no new CRUD). The only shared-code change was making `console/reference/_form.html.erb` field-type-aware (checkbox for boolean, number for integer) — a generic improvement that leaves geography/parties unchanged (confirmed by the still-green `console_reference_test`).
- Access is enforced server-side, not just hidden: `KitchenCabinet::TicketsController` redirects a user without `kitchen_cabinet` role access even on a direct URL (test covers this), in addition to the sidebar gate.
- Scope boundary respected: no `Ticket` model and no real list (Story 1.2 / 1.3). The stub index is clearly marked and only resolves the `?category=` slug + renders an empty state. Adding/removing a category touches no org-scoped table (AC 3).

### File List

- `db/migrate/20261006120000_create_ticket_categories.rb` (new)
- `db/schema.rb` (modified — ticket_categories)
- `app/models/ticket_category.rb` (new)
- `app/controllers/console/ticket_categories_controller.rb` (new)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (new)
- `app/views/kitchen_cabinet/tickets/index.html.erb` (new)
- `app/views/console/reference/_form.html.erb` (modified — boolean/integer field types)
- `app/views/ui/_sidebar.html.erb` (modified — org-side KC category submenu + permission gate)
- `app/views/ui/_console_sidebar.html.erb` (modified — "Ticket categories" link under Reference data)
- `config/routes.rb` (modified — console `ticket_categories` + `kitchen_cabinet` namespace)
- `db/seeds.rb` (modified — seed the 12 categories)
- `test/models/ticket_category_test.rb` (new)
- `test/integration/console_ticket_categories_test.rb` (new)
- `test/integration/kitchen_cabinet_nav_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.1 drafted (BMad create-story) — ticket-category global catalog via the Story 0.4 reusable editor + KC sidebar submenu/filter scaffolding. Status → ready-for-dev. |
| 2026-10-06 | Story 1.1 implemented (BMad dev-story) — `TicketCategory` model + migration + 12-category seed, Console catalog editor, type-aware shared `_form`, KC sidebar submenu with permission gate, and the `kitchen_cabinet/tickets` filter-target stub. 13 new tests; full suite 82/0, rubocop clean. Status → review. |
| 2026-10-06 | Fix: the Console sidebar had no link to the ticket-category editor (reachable only by URL) — added "Ticket categories" under Reference data, with a regression test. Full suite 83/0. |

## Status

review
