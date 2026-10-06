---
story_key: 1-3-browse-open-tickets
epic: 1
depends_on: 1-2-log-a-ticket
baseline_commit: 2024091e3591628742ea9db086f8b66001a8e9ce
---

# Story 1.3: Browse and open tickets (scoped list + detail)

Status: review

## Story

As a user,
I want to see and open the tickets I'm allowed to see,
So that I can work my branch's grievances.

## Acceptance Criteria

1. Given tickets exist in my subtree, when I open Kitchen Cabinet, then mobile shows a `ticket-card` list (person+village, category icon, status-pill, reported date); desktop shows the filterable center table with per-column filters (UX-DR10).
2. The list is scoped to viewer subtree ∩ organization ∩ module permission and is paginated; "Get All Details" never returns the raw table (FR4, NFR12).
3. Tapping a card/row opens the ticket detail with fields, attachments, follow-up log, status control, and the voter-gate field.

## Tasks / Subtasks

- [x] Task 1: Pagination (first listing in the app) (AC: 2)
  - [x] The installed `pagy` is **43.7.0** — a rewrite that replaces `Pagy::Backend`/`Pagy::Frontend` with `Pagy::Method` (`pagy(:offset, relation) → [@pagy, records]`). **Resolved (follow-up):** pinned `gem "pagy", "~> 43.7"`, `include Pagy::Method` in `ApplicationController`, and used `@pagy, @tickets = pagy(:offset, relation)` (default limit 20). The view pager uses the `@pagy` object (`page/last/previous/next`). The interim manual paginator was removed.
- [x] Task 2: Narrow the ticket Pundit scope + add `show?` (AC: 2, 3)
  - [x] `TicketPolicy::Scope#resolve` → `scope.kept.where(owner_id: user.subtree_user_ids)`; `show?` = `index? && record.owner_id.in?(user.subtree_user_ids)` (out-of-subtree → 404).
- [x] Task 3: Real index + show actions (AC: 1, 2, 3)
  - [x] `index` rebuilt: `policy_scope` base, `?category=`/`?status=`/`?q=` (ILIKE, Postgres) filters, ordered + manually paginated. "Get All Details" is the paginated scoped relation.
  - [x] `show` via `policy_scope(...).find` + `authorize`; `:show` added to the route.
  - [x] Soft-deleted excluded via the Scope's `.kept`.
- [x] Task 4: Views — mobile cards, desktop table, detail (AC: 1, 3)
  - [x] `_ticket_card.html.erb` (mobile whole-card link; person+village, category badge, status pill, reported date, ≥44px).
  - [x] `index.html.erb`: `ui/module_toolbar`, status+search GET filter form, desktop table (`hidden xl:block`, row click-through), mobile card list (`xl:hidden`), inline pager, empty-state, FAB retained.
  - [x] `show.html.erb`: full fields + attachment image previews + status pill, with clearly-labelled display-only placeholders for status control (1.4), voter-gate (1.6), and follow-up log (1.5).
  - [x] Category icon: first-letter badge (no icon column added), as flagged.
- [x] Task 5: Tests + verify (AC: all)
  - [x] `test/integration/kitchen_cabinet_browse_test.rb` (8 tests): subtree-only list, category+status filters, pagination split (25 → 2 pages), discarded excluded, in-subtree detail renders, out-of-subtree + other-org → 404, read-only can browse / no-access redirected.
  - [x] `bin/rails test` → 101 runs / 379 assertions / 0 failures; `bin/rubocop` → 114 files, 0 offenses.

## Dev Notes

- **Scope is the whole point of this story.** The three-way guard is: organization (acts_as_tenant, automatic) ∩ viewer subtree (`owner_id ∈ user.subtree_user_ids`, Story 0.9) ∩ module permission (the controller `require_kitchen_cabinet_access` + policy). Enforce subtree in the **policy Scope**, not ad-hoc in the controller, and read lists through `policy_scope(...)` — mirror `UserPolicy::Scope` (`scope.where(organization_id:, id: user.subtree_user_ids)`).
- **Reuse, don't reinvent:**
  - Pagination → `pagy` (already in the Gemfile for exactly this, NFR12). This is the first listing to use it; wire the Backend/Frontend includes once, centrally.
  - Status pill → `render "ui/status_pill", status: ticket.status` (exists; label+dot, never color-only, UX-DR5/DR7).
  - Module toolbar → `render "ui/module_toolbar"` (exists; buttons are wired to real export in Story 1.8 — leave them as-is here).
  - Soft-delete → list/`show` use Discard's `.kept` (the model already `include SoftDeletable`); never show discarded rows.
  - Category filter param `?category=<slug>` is the one established in Stories 1.1/1.2 — keep it consistent so the sidebar submenu + FAB keep working.
- **Scope boundary (do NOT build):** status transitions + `TicketStatusChange` (Story 1.4), follow-up creation (1.5), voter-ID gating/unlock (1.6), 2-step closure + sentiment (1.7), Excel/chart export + dashboard widget (1.8). This story is the **read** surface only — list + detail *display*. The detail page shows placeholder sections for the interactive pieces those stories deliver.
- **UX (UX-DR9/DR10/DR14):** three-level mobile IA (category list → `ticket-card` list → detail); mobile cards, desktop table with per-column filters; 44px targets; skeleton/empty states. Party accent only via the existing CSS vars.

### Project Structure Notes

- Controller: extend `app/controllers/kitchen_cabinet/tickets_controller.rb` (index/show).
- Policy: extend `app/policies/kitchen_cabinet/ticket_policy.rb` (Scope + show?).
- Pagy includes: `app/controllers/application_controller.rb` + `app/helpers/application_helper.rb`.
- Views: `app/views/kitchen_cabinet/tickets/{index,show}.html.erb` + `_ticket_card.html.erb`.
- Route: `namespace :kitchen_cabinet { resources :tickets, only: %i[index new create show] }`.

### References

- [Source: docs/epics.md#Story-1.3] — AC (BDD), FR4, NFR12, UX-DR10.
- [Source: docs/architecture.md#Routes] (`kitchen_cabinet` tickets) and #policies (`<module>/<model>_policy.rb`, scope reused everywhere); ui partials `_ticket_card`, `_status_pill`, `_data_table`.
- [Source: app/policies/user_policy.rb] — the Scope pattern (subtree ∩ org) to mirror.
- [Source: app/models/user.rb] — `subtree_user_ids` (cached, Story 0.9).
- [Source: app/models/kitchen_cabinet/ticket.rb] — `owner`, `ticket_category`, `attachments`, `status` enum, `SoftDeletable` (`.kept`).
- [Source: app/views/ui/_status_pill.html.erb] and [_module_toolbar.html.erb] — reuse as-is.
- [Source: docs/stories/1-2-log-a-ticket.md] — the controller/policy/stub this story extends; the `scope: :ticket` namespaced-form lesson.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails test` → 101 runs, 379 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 114 files, 0 offenses.

### Completion Notes List

- **Pagy (resolved).** The Gemfile's `pagy` was unpinned and floated to **43.7.0** — a genuine (verified authentic: ddnexus/Domizio Demichelis, MIT) rewrite that renames the mixins to `Pagy::Method` (no more `Backend`/`Frontend`). Initially shipped a manual paginator to avoid guessing; then adopted the real 43.x API: `include Pagy::Method`, `@pagy, @tickets = pagy(:offset, relation)` (default limit 20), view pager off the `@pagy` object (`page/last/previous/next`), and **pinned `gem "pagy", "~> 43.7"`** so it can't drift again. The root cause was the unpinned gem.
- **Scope enforced in the policy, not the controller:** `TicketPolicy::Scope` narrows to `kept ∩ owner∈subtree` (org via acts_as_tenant); the controller reads everything through `policy_scope`. Mirrors `UserPolicy::Scope`. Out-of-subtree / other-org `show` → 404 (RecordNotFound), consistent with the no-403 rule.
- Filters: category (sidebar `?category=`), status (enum-validated), and `?q=` ILIKE on person/village (Postgres). Ordered newest-first.
- Detail page shows display-only placeholders for status control (1.4), voter-gate (1.6), and follow-up log (1.5) so it reads as complete without implementing those behaviors.
- Category "icon" = first-letter badge; no icon column added (flagged product gap).
- Scope respected: no status transitions, follow-up writes, voter gating, closure, or export here.

### File List

- `Gemfile` / `Gemfile.lock` (modified — pin `pagy ~> 43.7`)
- `app/controllers/application_controller.rb` (modified — `include Pagy::Method`)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (modified — real index + show + pagy pagination)
- `app/policies/kitchen_cabinet/ticket_policy.rb` (modified — subtree/kept Scope + show?)
- `app/views/kitchen_cabinet/tickets/index.html.erb` (modified — table + cards + filters + pager + FAB)
- `app/views/kitchen_cabinet/tickets/show.html.erb` (new — ticket detail)
- `app/views/kitchen_cabinet/tickets/_ticket_card.html.erb` (new — mobile card)
- `config/routes.rb` (modified — tickets `:show`)
- `test/integration/kitchen_cabinet_browse_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.3 drafted (BMad create-story) — scoped, paginated browse list (mobile cards + desktop filterable table) + ticket detail; subtree∩org∩permission scoping via the Pundit Scope. Status → ready-for-dev. |
| 2026-10-06 | Story 1.3 implemented (BMad dev-story) — real scoped/filtered/paginated index, ticket detail, `_ticket_card`, subtree Pundit Scope + `show?`. Interim manual paginator pending a pagy decision. 8 new tests; full suite 101/0, rubocop clean. Status → review. |
| 2026-10-06 | Follow-up: investigated pagy — authentic gem, unpinned → floated to the 43.x rewrite (`Pagy::Method`). Adopted the real API (`include Pagy::Method`, `pagy(:offset, relation)`) and **pinned `gem "pagy", "~> 43.7"`**; removed the interim manual paginator. Full suite 101/0, rubocop clean. |

## Status

review
