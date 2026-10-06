---
story_key: 1-8-dashboard-widget-export
epic: 1
depends_on: 1-7-closure-sentiment
baseline_commit: de68027cef2d093dfd038896516657fafb1602c1
---

# Story 1.8: Kitchen Cabinet dashboard widget and export

Status: review

## Story

As a user,
I want Kitchen Cabinet to surface on the dashboard and export,
So that I can monitor and report on grievances.

## Acceptance Criteria

1. Given the dashboard framework (Story 0.14), when Kitchen Cabinet contributes its widget, then an "open tickets by status" widget renders **only for roles permitted on the module**, **scoped to the viewer's subtree** (FR50).
2. The filtered ticket table **exports to Excel**, scoped to the viewer; a Bar/Pie/Line **chart of the status breakdown** is presented (FR49).
3. Counts use **tabular figures** (UX-DR6).

## Tasks / Subtasks

- [x] Task 1: Module-widget delegation in the shared dashboard framework (AC: 1)
  - [x] `ui/_dashboard_widget.html.erb` renders a per-module body by convention (`"#{widget[:mod]}/dashboard_widget"` via `lookup_context.exists?`), else the placeholder — generic, reusable for every module.
  - [x] Reused the existing `dashboard_widgets_for` registration + `can_access?` gating (no duplication).
- [x] Task 2: Kitchen Cabinet dashboard widget body (AC: 1, 3)
  - [x] `kitchen_cabinet/_dashboard_widget.html.erb`: per-status counts via `policy_scope` (org ∩ subtree ∩ kept), `tabular-nums` figures + `ui/status_pill` per row, a `pie_chart`, and a link to the list.
- [x] Task 3: Excel export of the scoped, filtered list (AC: 2)
  - [x] `index` `respond_to` html/xlsx off the same relation; `format.xlsx` exports the full unpaginated scoped/filtered set with a `Content-Disposition` attachment header.
  - [x] `index.xlsx.axlsx` (caxlsx_rails) — header + one row per ticket. `caxlsx_rails` auto-registered `:xlsx` (no initializer needed).
  - [x] Scoped by construction (reuses `policy_scope`).
- [x] Task 4: Wire the toolbar's Export + present the chart (AC: 2)
  - [x] `ui/_module_toolbar.html.erb` gained an optional `export_url` local (Export Excel → link when present; plain button otherwise) — generic/reusable.
  - [x] KC index renders the toolbar with `export_url` carrying the current filters (+ `format: :xlsx`).
  - [x] Chartkick `pie_chart` rendered in the widget. **Flagged/deferred:** chartkick JS adapter not pinned, so the chart does not visually draw yet; chart-image export + the Bar/Pie/Line live toggle remain non-wired placeholders (client-side; Minimal-Hotwire posture).
- [x] Task 5: Tests + verify (AC: all)
  - [x] `kitchen_cabinet_dashboard_test.rb`: widget present for a KC-permitted user, absent for a no-access user.
  - [x] `kitchen_cabinet_export_test.rb`: xlsx → `:success` + spreadsheet content type; **Roo-parsed** to assert subtree scoping (peer absent) and `?status=` filter narrowing.
  - [x] `bin/rails test` → 143 runs / 506 assertions / 0 failures; `bin/rubocop` → 132 files, 0 offenses.

## Dev Notes

- **This closes Epic 1 by wiring KC into the two Story 0.14 frameworks** — the widget-composition dashboard and the shared export toolbar. The whole point is *no module-specific code in the frameworks*: the generic `_dashboard_widget` gains a convention (`<mod>/dashboard_widget` partial) and the generic `_module_toolbar` gains an optional `export_url`. Both stay reusable for Epics 2–7.
- **Scope = viewer, always.** Both the widget counts and the Excel rows go through `policy_scope(KitchenCabinet::Ticket)` (org ∩ subtree ∩ kept, Story 1.3). The export must reuse the exact same relation/filters as the list — never a raw `KitchenCabinet::Ticket.all`.
- **Reuse, don't reinvent:**
  - Dashboard registration + module-permission gating already live in `dashboard_widgets_for` (Story 0.14) — just fill the body.
  - Pagination (pagy) stays on `format.html`; the xlsx path is intentionally unpaginated (export the full scoped set).
  - `caxlsx_rails` provides the `.xlsx.axlsx` view DSL; `roo` (already in the Gemfile) parses xlsx in tests.
  - `ui/status_pill` for per-status rows; `tabular-nums` Tailwind utility for UX-DR6.
- **Current state of files being changed:**
  - `app/views/ui/_dashboard_widget.html.erb` — currently renders title + a static "Populated by its module epic." line; add the per-module body delegation.
  - `app/views/ui/_module_toolbar.html.erb` — Export Excel is a static `<button>`; make it a link when `export_url` is given (keep all other buttons as-is).
  - `app/controllers/kitchen_cabinet/tickets_controller.rb` — `index` builds the relation then paginates; wrap in `respond_to` and add the xlsx branch (don't change the html branch's behaviour).
  - `app/views/kitchen_cabinet/tickets/index.html.erb` — pass `export_url` into the toolbar render.
- **UX-DR6:** every count/number (widget tallies, ticket numbers) uses tabular figures (`tabular-nums`). RAG/status colour is presentation only (labels carry meaning).
- **Scope boundary / known limitation (flag for review):** chart *image* export and the Bar/Pie/Line live toggle are **not** implemented — chartkick's JS adapter isn't pinned and that's a client-side charting concern (consistent with the architecture's Minimal-Hotwire posture). The chart helper is rendered but won't draw until a charting lib is wired in a later pass. The RAG rollup that aggregates this data across the constituency is **Epic 7**, not here. Voter-list exports (and their logging, FR49) are **Epic 6**.

### Project Structure Notes

- New: `app/views/kitchen_cabinet/_dashboard_widget.html.erb`, `app/views/kitchen_cabinet/tickets/index.xlsx.axlsx`, tests.
- Modify: `app/views/ui/_dashboard_widget.html.erb`, `app/views/ui/_module_toolbar.html.erb`, `app/controllers/kitchen_cabinet/tickets_controller.rb`, `app/views/kitchen_cabinet/tickets/index.html.erb`.
- Possibly new: `config/initializers/mime_types.rb` (only if `caxlsx_rails` doesn't auto-register `:xlsx`).
- No migration, no new model.

### References

- [Source: docs/epics.md#Story-1.8] — AC (BDD); FR49 (line 89), FR50 (line 90), UX-DR6 (line 169).
- [Source: docs/project_brief.md §5/§6.1] — module toolbar (Export Excel/Chart) + "open tickets by status" dashboard surface.
- [Source: docs/architecture.md] — `services/exports/(excel_export, chart_export)` (line 292); chartkick/caxlsx/roo in the stack (lines 44, 242); `_dashboard_widget` framework.
- [Source: app/helpers/application_helper.rb] — `dashboard_widgets_for` (the KC widget is registered + gated here).
- [Source: app/views/ui/_dashboard_widget.html.erb] + [_module_toolbar.html.erb] — the generic partials to extend.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — `Scope` (org ∩ subtree ∩ kept) reused for widget + export.
- [Source: app/controllers/kitchen_cabinet/tickets_controller.rb] — `index` relation/filters/pagy to extend with the xlsx branch.
- [Source: docs/stories/1-3-browse-open-tickets.md] — the scoped/filtered relation + pagy this story extends.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails test` → 143 runs, 506 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 132 files, 0 offenses.
- `caxlsx_rails` auto-registers the `:xlsx` MIME type — `format.xlsx` worked without an initializer.
- No migration.

### Completion Notes List

- **Both frameworks stayed generic:** `ui/_dashboard_widget` now renders `"#{widget[:mod]}/dashboard_widget"` by convention (every future module drops in its own body — no framework edits), and `ui/_module_toolbar` gained an optional `export_url` (Export Excel becomes a link). The dashboard, which renders the toolbar without `export_url`, is unaffected.
- **Scope everywhere via `policy_scope`:** the widget counts and the Excel rows both go through `KitchenCabinet::TicketPolicy::Scope` (org ∩ subtree ∩ kept). The export reuses the exact same relation + filters as the HTML list — the xlsx path just skips pagination. A Roo-parsed test proves a peer's ticket is excluded and `?status=` narrows the rows.
- **UX-DR6:** widget counts use `tabular-nums`.
- **⚠️ Flagged (deferred, for review):** chartkick's JS adapter is not pinned (no chart lib in importmap), so the `pie_chart` renders a container but does not visually draw yet; chart-image export + the Bar/Pie/Line live toggle are left as non-wired placeholders. These are client-side charting concerns, intentionally out of scope here (Minimal-Hotwire posture) — a later pass can pin a charting lib. The Excel export (the concrete FR49 deliverable) is fully working + tested.
- **Scope boundary:** the cross-module RAG rollup that aggregates this data is Epic 7; Voter-list exports + their logging are Epic 6 — not here.

### File List

- `app/views/ui/_dashboard_widget.html.erb` (modified — per-module body delegation)
- `app/views/kitchen_cabinet/_dashboard_widget.html.erb` (new — KC widget body)
- `app/views/ui/_module_toolbar.html.erb` (modified — optional `export_url`)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (modified — `respond_to` html/xlsx)
- `app/views/kitchen_cabinet/tickets/index.xlsx.axlsx` (new — caxlsx export template)
- `app/views/kitchen_cabinet/tickets/index.html.erb` (modified — toolbar `export_url`)
- `test/integration/kitchen_cabinet_dashboard_test.rb` (new)
- `test/integration/kitchen_cabinet_export_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.8 drafted (BMad create-story) — KC "open tickets by status" dashboard widget (gated + subtree-scoped, tabular figures) via a generic `<mod>/dashboard_widget` convention, and a viewer-scoped Excel export (caxlsx_rails, roo-tested) wired through an `export_url` on the shared toolbar. Chart-image export flagged as a deferred client-side concern. No migration. Status → ready-for-dev. |
| 2026-10-06 | Story 1.8 implemented (BMad dev-story) — generic module-widget delegation + KC "open tickets by status" widget (scoped, tabular), viewer-scoped Excel export (caxlsx_rails) wired via a reusable toolbar `export_url`, Roo-tested scoping/filtering. Chart-image export deferred (chartkick JS not pinned). 4 new tests; full suite 143/0, rubocop clean. Status → review. |

## Status

review
