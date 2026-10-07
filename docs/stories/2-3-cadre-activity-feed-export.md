---
story_key: 2-3-cadre-activity-feed-export
epic: 2
depends_on: 2-2-per-category-detail-forms
baseline_commit: 597d5ae7d31f9b1d6ae955812cf3381da3a873e2
---

# Story 2.3: Cadre activity feed and export

Status: review

## Story

As a user,
I want recent cadre activity in one feed and exportable,
so that I can review and report on organizing work.

## Acceptance Criteria

1. Given cadre activities exist, when the dashboard feed runs, then "Recent cadre activity" is a query over `cadre_activities` (not a union of the five detail tables), scoped to the viewer's organization and subtree, and discarded rows are excluded (FR26).
2. The feed renders as the dashboard widget already registered for `cadre_program`, and only for a role that can access that module (FR50).
3. The filtered activity list exports to Excel. The file contains the same scoped, filtered rows as the list, unpaginated. A category breakdown chart of that filtered set is shown on the list (FR49).

## Tasks / Subtasks

- [x] Task 1: Dashboard widget (AC: 1, 2)
  - [x] `app/views/cadre_program/_dashboard_widget.html.erb`. `policy_scope(CadreProgram::CadreActivity)` only — recent rows (`order(created_at: :desc).limit(5)`, owner included) plus `group(:category)` counts. No detail-table union.
  - [x] Counts use `tabular-nums` and a text label per category, then `pie_chart`. Link to the list. Empty state: "No cadre activity yet."
  - [x] Do not edit `dashboard_widgets_for` or `ui/_dashboard_widget.html.erb`. The convention already looks up `cadre_program/dashboard_widget`.
- [x] Task 2: Excel export and list chart (AC: 3)
  - [x] `index` `respond_to` html/xlsx. HTML stays paginated. `format.xlsx` exports the full filtered relation (category and media-value search) with `Content-Disposition` `cadre_program_activities.xlsx`.
  - [x] `index.xlsx.axlsx`: Date, Category, Activity, Media value, Logged by, Photos.
  - [x] Index passes `export_url` into `ui/module_toolbar`, preserving `category` and `q`. Render a labeled category-count list and `pie_chart` for the filtered set.
  - [x] Chart-image download and the Bar/Pie/Line toggle stay the inert toolbar buttons. Chartkick's JS adapter is not pinned (same boundary as Story 1.8). Do not add a gem.
- [x] Task 3: Tests (AC: all)
  - [x] Dashboard: a permitted user sees "Recent cadre activity" and their own notes; a peer's notes are absent; a role without `cadre_program` does not see the widget title.
  - [x] Export: Roo-parsed xlsx is `success` with the spreadsheet content type; subtree scoping; `?category=` drops the other category; a user without module access is redirected.
  - [x] `bin/rails test` and `bin/rubocop` stay green.

## Dev Notes

- **The feed is the base table.** `CadreActivity` is already the scoped list. Do not query the five detail tables and combine them. `detail_headline` may be used on the Excel sheet (eager-load the has_ones there). The widget itself shows category, media value, owner, and date from the base row plus `owner`.
- **Scope = viewer, always.** Widget counts, recent rows, the list chart, and the xlsx rows all start from `policy_scope` (organization via acts_as_tenant, subtree, `kept`). Never `CadreActivity.all` or `unscoped`.
- **Reuse Story 1.8.** `caxlsx_rails` already registers `:xlsx`. Parse exports with `roo`. `pie_chart` is the chartkick helper Kitchen Cabinet already renders. Pagination stays on `format.html` only.
- **Do not touch the frameworks.** `application_helper.rb#dashboard_widgets_for` already registers `{ title: "Recent cadre activity", mod: "cadre_program" }` and gates it with `can_access?`. `ui/_dashboard_widget` already renders `cadre_program/dashboard_widget` when the partial exists.
- **Filters travel together.** Category (`@category_key`) and `q` (impact notes ILIKE) apply to the HTML list, the chart counts, and the xlsx. `group(:category).count` must `reorder(nil)` first — PostgreSQL rejects `ORDER BY created_at` next to `GROUP BY category`. Map enum keys (integer or string) through `CATEGORY_LABELS`.
- **Chart limitation (same as 1.8).** `pie_chart` renders a container. It will not draw until a charting library is pinned. Do not add Chart.js in this story. "Export Chart" stays a button. The labeled count list is the accessible chart.
- **No migration. No new model. No new gem.**

### Project Structure Notes

- New: `app/views/cadre_program/_dashboard_widget.html.erb`, `app/views/cadre_program/activities/index.xlsx.axlsx`, `test/integration/cadre_program_feed_test.rb`.
- Modify: `app/controllers/cadre_program/activities_controller.rb`, `app/models/cadre_program/cadre_activity.rb` (`counts_by_category`), `app/views/cadre_program/activities/index.html.erb`.
- Leave unchanged: `app/helpers/application_helper.rb`, `app/views/ui/_dashboard_widget.html.erb`, `app/views/ui/_module_toolbar.html.erb`, Kitchen Cabinet files, `Gemfile`.

### References

- [Source: docs/epics.md#Story-2.3] — FR26 feed, FR50 widget, FR49 export.
- [Source: docs/stories/1-8-dashboard-widget-export.md] — widget partial convention, `format.xlsx`, Roo tests, chart-image deferral.
- [Source: docs/stories/2-1-cadre-activity-base-capture.md] — the list relation this story exports. Do not redo capture.
- [Source: app/controllers/kitchen_cabinet/tickets_controller.rb] — `respond_to` html/xlsx.
- [Source: app/views/kitchen_cabinet/_dashboard_widget.html.erb] — scoped counts, `tabular-nums`, `pie_chart`.
- [Source: app/helpers/application_helper.rb] — widget already registered; do not edit.

## Dev Agent Record

### Agent Model Used

Grok 4.7 (BMad create-story, then dev-story)

### Debug Log References

- Feed tests failed first: widget body still said "Populated by its module epic"; `format.xlsx` returned 406.
- `bin/rails test` → 174 runs, 749 assertions, 0 failures. `bin/rubocop` → 149 files, 0 offenses.

### Completion Notes List

- Ultimate context engine analysis completed — comprehensive developer guide created.
- Dashboard widget lists the five most recent activities from `cadre_activities` (policy scope), with a labeled category count and a pie chart. A peer outside the viewer's subtree is omitted. A role without Cadre Program access does not see the widget.
- The activity list exports the same filtered rows to Excel (unpaginated) and shows the category breakdown for that filter. Chart-image download stays a placeholder, same as Story 1.8. No new gem.

### File List

- `app/models/cadre_program/cadre_activity.rb` (modified — `counts_by_category`)
- `app/controllers/cadre_program/activities_controller.rb` (modified — html/xlsx)
- `app/views/cadre_program/_dashboard_widget.html.erb` (new)
- `app/views/cadre_program/activities/index.html.erb` (modified — toolbar + chart)
- `app/views/cadre_program/activities/index.xlsx.axlsx` (new)
- `test/integration/cadre_program_feed_test.rb` (new)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-07 | Story 2.3 drafted (BMad create-story) — dashboard feed over `cadre_activities`, module-gated widget, viewer-scoped Excel export and category chart. Chart-image download stays deferred with Story 1.8. Status → ready-for-dev. |
| 2026-10-07 | Story 2.3 implemented (BMad dev-story) — widget, Excel export, category chart. Full suite 174/0, rubocop clean. Status → review. |

## Status

review
