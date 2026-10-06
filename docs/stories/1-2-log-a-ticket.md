---
story_key: 1-2-log-a-ticket
epic: 1
depends_on: 1-1-ticket-categories-sidebar-nav
baseline_commit: 3e7375169136508ead5a60f82ebfbd413cecc677
---

# Story 1.2: Log a ticket (mobile-first capture)

Status: review

## Story

As a field user with Kitchen Cabinet write access,
I want to log a grievance in a few taps, pre-filled to a category,
So that I can capture an issue with a constituent in front of me.

## Acceptance Criteria

1. Given a user on the mobile Kitchen Cabinet surface, when they tap the party-accented **new-ticket FAB** from a category, then a `tickets` record is created with: `owner` (the creating user), `organization`, `ticket_category`, person/represents (name + village), village/ward, mobile, description, attachments, reported date, nature of issue, reported value, and `status` defaulting to `open` (FR19).
2. The form is pre-filled to the active category and all touch targets are ≥44px (UX-DR9, UX-DR14).
3. Attachments (photos) upload via Active Storage.
4. The record carries `organization_id` and passes the per-model isolation test (FR2, FR11).

## Tasks / Subtasks

- [x] Task 1: `KitchenCabinet::Ticket` model + `tickets` migration (AC: 1, 3, 4)
  - [x] Migration `create_table :tickets` with the full brief §6.1 column set (owner/org/category FKs, ticket_number, person_name null-false, village, mobile, description, reported_at null-false, closed_at, voter_id, nature_of_issue, reported_value decimal(12,2), status default 0, discard columns). Only 1.2 behavior wired; voter_id/closed_at/status-workflow deferred.
  - [x] Indexes: FK references index org/category/owner; `discarded_at`; unique `[organization_id, ticket_number]`.
  - [x] Model `KitchenCabinet::Ticket` with `self.table_name = "tickets"`; `include OrganizationScoped` + `SoftDeletable`; `belongs_to :owner` (User) + `:ticket_category` (TicketCategory); `has_many_attached :attachments`; `enum :status … default: :open`; `person_name` presence; `reported_at` defaults to today.
  - [x] `ticket_number` auto-assigned per org on create (`KC-<org>-<nnnnn>`, via unscoped per-org count), guarded by the unique index.
- [x] Task 2: Routes + controller capture actions (AC: 1, 2)
  - [x] Route changed to `resources :tickets, only: %i[index new create]`.
  - [x] `KitchenCabinet::TicketsController#new`/`#create` added (index stub + `require_kitchen_cabinet_access` kept); `owner = current_user`, org via acts_as_tenant, redirect to the category list on success.
  - [x] Strong params permit only capture fields (+`attachments: []`); never `owner_id`/`organization_id`/`status`/`voter_id`/`closed_at`.
- [x] Task 3: Authorization (AC: 1, 4)
  - [x] `KitchenCabinet::TicketPolicy` — read on `can_access?`, create/new on `can_write?`; permissive Scope (subtree narrowing deferred to 1.3).
  - [x] `authorize @ticket` in `new`/`create`; denial → 404 via the existing `rescue_from Pundit::NotAuthorizedError`.
- [x] Task 4: Mobile-first capture form + party-accented FAB (AC: 1, 2, 3)
  - [x] `tickets/new.html.erb`: single-column form, category pre-filled (hidden `ticket_category_id` + visible label), fields incl. `file_field :attachments, multiple:`; ≥44px targets (`min-h-11`); `scope: :ticket` set so the namespaced model's params stay `ticket[...]`.
  - [x] Party-accented new-ticket FAB added to the `index` stub (shown when a category is selected), linking to the pre-filled form.
- [x] Task 5: Tests + verify (AC: all)
  - [x] Model test (`test/models/kitchen_cabinet/ticket_test.rb`): OrganizationScoped, status default, person_name required, owner/category/attachments/ticket_number, `assert_raises_without_tenant`, `assert_tenant_isolated` (release-gate isolation).
  - [x] Integration test (`test/integration/kitchen_cabinet_tickets_test.rb`): pre-filled form, create-with-attachment (owner+org from session), org-from-params ignored, read-only user → 404.
  - [x] `bin/rails test` → 93 runs / 344 assertions / 0 failures; `bin/rubocop` → 113 files, 0 offenses.

## Dev Notes

- **This is the first org-scoped *domain* model** (vs. the global catalogs so far). Isolation is non-negotiable: `include OrganizationScoped` gives `acts_as_tenant(:organization)` + `organization_id` presence, and the request tenant is already set by `ApplicationController#set_current_organization` (= `current_user.organization`). So in the controller you do **not** set `organization_id` — acts_as_tenant assigns it, and a missing tenant raises by design. A per-model isolation test is a **release blocker** (see `test/support/tenant_isolation.rb`).
- **Reuse, don't reinvent:**
  - Soft-delete → `include SoftDeletable` (Story 0.10) — do not add your own delete. (1.2 only creates; delete UI comes later, but the columns + concern belong on the model now.)
  - Auth → Pundit policy + the existing `rescue_from Pundit::NotAuthorizedError → 404` in `ApplicationController`. Module-permission helpers are `current_user.role.can_access?/can_write?("kitchen_cabinet")` (Story 0.8).
  - Attachments → Active Storage is already installed (Story 0.7 migration; `has_one_attached`/`has_many_attached` used on `User`/`Party`/`Politician`). Use `has_many_attached :attachments`.
  - Category pre-fill reads the `?category=<slug>` param established in Story 1.1 (`TicketCategory.active.find_by(slug:)`).
- **Scope boundary (do NOT build):** status workflow + `TicketStatusChange` (Story 1.4), follow-up log (1.5), voter-ID gating (1.6), 2-step closure + sentiment write to `Voter` (1.7), dashboard widget + Excel/chart export (1.8), and the full scoped/paginated browse list + ticket detail (1.3). The 1.1 `index` stub stays a placeholder; this story only adds `new`/`create` + the FAB.
- **UX discipline (DESIGN.md / UX-DR9/DR14):** mobile-first single column; 44px targets; party accent as **accent only** via the `--org-party-color`/`--org-party-contrast` CSS vars already on `<body>` (layout from Story 0.14); no full-surface theming; Independent orgs fall back automatically. Skeleton/empty states per UX-DR14 are nice-to-have, not required for 1.2.
- **`reported_value` type is ambiguous in the brief** — modeled here as `decimal(12,2)` (a monetary estimate of the issue). If product intent differs, this is the one field to confirm; flag it in review rather than guessing further.

### Project Structure Notes

- Model: `app/models/kitchen_cabinet/ticket.rb` (architecture §Project Structure line 274, namespaced `KitchenCabinet::`). **Deviation note vs. Story 1.1:** 1.1 kept `TicketCategory` top-level because it is *global reference data* like `Party`/`Role`; `Ticket` is a genuine org-scoped KC *domain* model that will be joined by `TicketFollowUp`/`TicketStatusChange`, so it **is** namespaced per architecture. The `self.table_name = "tickets"` pin keeps the physical table name from the brief.
- Controller: `app/controllers/kitchen_cabinet/tickets_controller.rb` (already exists from 1.1 — extend it).
- Policy: `app/policies/kitchen_cabinet/ticket_policy.rb` (new; architecture §policies `<module>/<model>_policy.rb`).
- Views: `app/views/kitchen_cabinet/tickets/{new,index}.html.erb`.
- Route: `namespace :kitchen_cabinet` in `config/routes.rb` (extend the 1.1 `resources :tickets`).

### References

- [Source: docs/epics.md#Story-1.2] — AC (BDD), FR19, UX-DR9/UX-DR14.
- [Source: docs/project_brief.md §6.1] — `Ticket` record fields + status enum (`open/in_progress/closed/blocked`) + the "org-scoped tickets under a global category" rule; data dictionary lines 387-388.
- [Source: docs/architecture.md#Routes] (lines 344-352, `namespace :kitchen_cabinet { resources :tickets }`) and #Project-Structure (model/controller/policy locations), #Data-boundary (acts_as_tenant layers).
- [Source: app/controllers/application_controller.rb] — `set_current_tenant_through_filter` + `set_current_organization`; `rescue_from Pundit::NotAuthorizedError → 404`.
- [Source: app/models/voter.rb] — the existing `include OrganizationScoped` domain-model pattern.
- [Source: app/models/concerns/{organization_scoped,soft_deletable}.rb] — the concerns to include.
- [Source: test/support/tenant_isolation.rb] and [test/models/tenant_isolation_spine_test.rb] — the mandatory isolation-test helpers + usage.
- [Source: app/policies/user_policy.rb] — Pundit policy + Scope pattern to mirror.
- [Source: docs/stories/1-1-ticket-categories-sidebar-nav.md] — the `KitchenCabinet::TicketsController` stub, `?category=` param, and the top-level `TicketCategory` decision this story builds on.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails db:migrate` → `tickets` created cleanly.
- `bin/rails test` → 93 runs, 344 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 113 files, 0 offenses.

### Completion Notes List

- **Namespaced-model form-param bug caught in test (important).** `form_with model: @ticket` on `KitchenCabinet::Ticket` scopes params to `kitchen_cabinet_ticket[...]`, but the controller reads `params.require(:ticket)`. The real form would have silently failed to submit. Fixed by pinning `scope: :ticket` on the form — field names are now `ticket[...]`, matching the controller + tests. (The POST tests alone wouldn't have caught this since they post `ticket:` directly; the `assert_select` on the rendered hidden field did.)
- **Tenant discipline:** `organization_id` is never in strong params — acts_as_tenant assigns it from the request tenant (`current_user.organization`). A test proves a malicious `organization_id` in params is ignored. `Ticket.new` raises `NoTenantSet` outside a tenant, so model tests build inside `ActsAsTenant.with_tenant`/`without_tenant` (mirroring the spine test).
- **Release-gate isolation test present** for `KitchenCabinet::Ticket` via the shared `TenantIsolation` helpers (FR11).
- Authorization: read gated on `can_access?`, create on `can_write?`; a KC read-only user gets 404 (not 403) on create, consistent with the app-wide Pundit→404 convention.
- Scope respected: no status workflow (1.4), follow-ups (1.5), voter gate (1.6), closure/sentiment (1.7), export/widget (1.8), or full browse list (1.3). The `index` stub remains a placeholder (now with the FAB).

### File List

- `db/migrate/20261006130000_create_tickets.rb` (new)
- `db/schema.rb` (modified — tickets)
- `app/models/kitchen_cabinet/ticket.rb` (new)
- `app/policies/kitchen_cabinet/ticket_policy.rb` (new)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (modified — new/create + strong params)
- `app/views/kitchen_cabinet/tickets/new.html.erb` (new — capture form)
- `app/views/kitchen_cabinet/tickets/index.html.erb` (modified — party-accented FAB)
- `config/routes.rb` (modified — tickets `only: %i[index new create]`)
- `test/models/kitchen_cabinet/ticket_test.rb` (new)
- `test/integration/kitchen_cabinet_tickets_test.rb` (new)
- `test/fixtures/files/photo.png` (new — attachment fixture)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.2 drafted (BMad create-story) — mobile-first ticket capture: `KitchenCabinet::Ticket` (first org-scoped domain model, acts_as_tenant + soft-delete + Active Storage attachments), new/create actions, Pundit policy, pre-filled form + party-accented FAB. Status → ready-for-dev. |
| 2026-10-06 | Story 1.2 implemented (BMad dev-story) — model + migration + per-org ticket_number, write-gated new/create with org from session, mobile-first form (`scope: :ticket` fix) + FAB, Pundit policy, and the release-gate isolation test. 10 new tests; full suite 93/0, rubocop clean. Status → review. |

## Status

review
