---
story_key: 3-1-village-report-testimonials
epic: 3
depends_on: 0-9-hierarchical-user-management
baseline_commit: f70475e28d4abf2143155c23bed786fdc30017c3
---

# Story 3.1: Village report with testimonials

Status: review

## Story

As a user with Ground Reports access,
I want to record a village's issues and resolutions, and villager testimonials,
so that field intelligence is captured per village.

## Acceptance Criteria

1. Given a village in the signed-in organization's constituency, when a user with Ground Reports write access creates a report, a `GroundReport` row is saved with `village_id`, `organization_id`, `owner_id`, `issue_text`, `resolution_text`, and `reported_at` (FR27).
2. That report can hold many `GroundReportTestimonial` children. Each has `person_name`, `content_type` of text, audio, or video, `text_content` when the type is text, and an Active Storage file when the type is audio or video (FR27).
3. Both tables carry `village_id` is not required on the testimonial; both carry `organization_id`. The report carries `village_id`. Rows are soft-deletable. A report outside the viewer's subtree or organization is not visible (404, not 403). A village outside the organization's constituency is not selectable.
4. The sidebar shows Ground Reports only to roles that can access the module. Other modules stay on the "soon" list. No dashboard widget, Excel export, worship places, yatra, contacts, or mock poll in this story.

## Tasks / Subtasks

- [x] Task 1: Models and migration (AC: 1, 2, 3)
  - [x] `ground_reports` and `ground_report_testimonials` with organization_id NOT NULL, soft-delete columns, and Active Storage on the testimonial.
  - [x] Namespaced models `GroundReports::GroundReport` and `GroundReports::GroundReportTestimonial`. Pin table names. Include `OrganizationScoped` and `SoftDeletable`.
  - [x] Testimonial `content_type` enum `text` / `audio` / `video`. Text requires `text_content`. Audio and video require an attached file.
  - [x] Report village must belong to `organization.villages`. Ignore a posted `organization_id`.
- [x] Task 2: Village list, report capture, and show (AC: 1, 2, 4)
  - [x] `namespace :ground_reports` villages index/show and nested reports new/create/show plus testimonials create.
  - [x] `policy_scope` is kept reports whose owner is in the viewer subtree. Module read can browse. Module write can create. Missing module access redirects to root. Unauthorized record is 404.
  - [x] Sidebar link replaces the Ground Reports "soon" item, gated on `can_access?("ground_reports")`.
  - [x] Page header and table are separate. Party color stays on the header mark and the create control. The table stays neutral. Do not add a chart.
- [x] Task 3: Tests (AC: all)
  - [x] Model: text vs media validation, village outside the constituency rejected, organization isolation.
  - [x] Integration: permitted user creates a report with a text testimonial and an audio file; peer and other-org rows are hidden; read-only cannot create; no-access is redirected.
  - [x] Cadre nav test updated: Ground Reports is no longer a "soon" badge for a role without the module.

## Dev Notes

- **Village is global reference data.** `Organization#villages` already walks constituency → assemblies → villages. Do not tenant-scope `Village`. Select villages with `current_user.organization.villages`, never `Village.all`.
- **Namespaced models need pinned table names**, same as `CadreActivity` (`self.table_name = "ground_reports"`). Forms must use `scope: :ground_report` so params are not nested under `ground_reports_ground_report`.
- **Do not install a gem.** Active Storage, Pagy, Pundit, and Discard are already in the app. Media Value / Action Text is not used here. `issue_text` and `resolution_text` are `t.text`.
- **Do not build Stories 3.2–3.5.** No `WorshipPlace`, `VillageYatra`, `VillagePoliticalPosition`, local contacts, mock poll, or Excel import. Do not add `ground_reports/_dashboard_widget.html.erb`. The dashboard already shows "Populated by its module epic." until a later story.
- **Subtree scope matches Cadre and Kitchen Cabinet:** `scope.kept.where(owner_id: user.subtree_user_ids)`. `organization_id` comes from the tenant, never params. Call `record_activity("ground_report.created", record: @report)` on create.
- **UI learned from Epic 2:** header band and table are two blocks. Party color on the mark, count chip, and submit/plus. Table text and header stay gray. Status colors are not used on this page. Touch targets `min-h-11`. Submit is a `button`, not `input[type=submit]`.

### Project Structure Notes

- Models: `app/models/ground_reports/`
- Policies: `app/policies/ground_reports/`
- Controllers: `app/controllers/ground_reports/`
- Views: `app/views/ground_reports/villages/` and `reports/`
- Migration only. Do not edit `application_helper.rb` or `ui/_dashboard_widget.html.erb`.

### References

- [Source: docs/epics.md — Story 3.1, FR27]
- [Source: docs/project_brief.md — Report and GroundReportTestimonial columns]
- [Source: docs/architecture.md — `namespace :ground_reports` villages index/show]
- [Source: app/models/organization.rb — `Organization#villages`]
- [Source: app/policies/cadre_program/cadre_activity_policy.rb — subtree scope to copy]

## Dev Agent Record

### Agent Model Used

Grok 4.7

### Debug Log References

### Completion Notes List

- Village list is limited to `organization.villages`. A report stores issue, resolution, and reported date, and accepts nested testimonials. More testimonials can be added on the show page.
- Text testimonials store `text_content`. Audio and video require an Active Storage attachment. A posted `organization_id` is not permitted.
- Sidebar shows Ground Reports only with module access. Full suite 188 runs, 820 assertions, 0 failures. Rubocop clean on the new Ruby files.

### File List

- `db/migrate/20261008010000_create_ground_reports.rb` (new)
- `db/schema.rb` (modified)
- `app/models/ground_reports/ground_report.rb` (new)
- `app/models/ground_reports/ground_report_testimonial.rb` (new)
- `app/models/village.rb` (modified)
- `app/policies/ground_reports/ground_report_policy.rb` (new)
- `app/policies/ground_reports/ground_report_testimonial_policy.rb` (new)
- `app/controllers/ground_reports/villages_controller.rb` (new)
- `app/controllers/ground_reports/reports_controller.rb` (new)
- `app/controllers/ground_reports/testimonials_controller.rb` (new)
- `app/views/ground_reports/villages/index.html.erb` (new)
- `app/views/ground_reports/villages/show.html.erb` (new)
- `app/views/ground_reports/reports/new.html.erb` (new)
- `app/views/ground_reports/reports/show.html.erb` (new)
- `app/views/ground_reports/testimonials/_fields.html.erb` (new)
- `app/views/ui/_sidebar.html.erb` (modified)
- `config/routes.rb` (modified)
- `test/models/ground_reports/ground_report_test.rb` (new)
- `test/integration/ground_reports_test.rb` (new)
- `test/integration/cadre_program_nav_test.rb` (modified)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 3.1 drafted — village report plus text/audio/video testimonials, constituency-limited villages, subtree/org scope. Worship, contacts, mock poll, import, and the dashboard widget stay out. Status → ready-for-dev. |
| 2026-10-08 | Story 3.1 implemented — village list, report capture, text/audio/video testimonials, subtree scope. Full suite 188/0, rubocop clean. Status → review. |

## Status

review
