---
story_key: 3-5-bulk-excel-import-report-mock-poll
epic: 3
depends_on: 3-4-mock-poll-capture-tally
baseline_commit: f70475e28d4abf2143155c23bed786fdc30017c3
---

# Story 3.5: Bulk Excel import for Report and Mock Poll

Status: review

## Story

As a reporting agency with a scoped import role,
I want to bulk-import survey and report data,
so that large datasets enter the system without manual re-entry.

## Acceptance Criteria

1. A role with `can_import` and Ground Reports access can upload an Excel file of reports or mock-poll responses. `roo` parses the sheet. Each good row becomes a `GroundReport` or `MockPollResponse` owned by the importing user and stamped with that user's organization (FR31).
2. The import uses the same scope as hand entry. A report is visible only in the importer's subtree. A mock-poll response is visible to the organization. A village outside the constituency is not imported. Spreadsheet columns for organization or owner are ignored.
3. A bad row is reported with its spreadsheet row number and does not stop the other rows. A file that is not a workbook is reported as an error and imports nothing. A user without `can_import` cannot upload.

## Tasks / Subtasks

- [x] Task 1: Import capability and records (AC: 1, 3)
  - [x] `roles.can_import`, default false. Console role form and list can set it. Do not turn it on for the seeded system roles.
  - [x] `ground_report_imports` stores kind, status, imported count, row errors, and the uploaded file. The importing user and organization come from the session.
- [x] Task 2: Parsers and job (AC: 1, 2, 3)
  - [x] `Imports::BaseImporter` reads the first sheet with `roo`. `GroundReportImporter` and `MockPollImporter` map rows. `ImportGroundReportsJob` runs the matching importer.
  - [x] Report columns: village, issue, resolution, reported_at. Mock poll columns: village, politician, respondent_name, respondent_mobile, preference_basis, vote_intent, note.
  - [x] Save each good row on its own. Collect row errors and continue.
- [x] Task 3: Import page (AC: 1, 3)
  - [x] `ground_reports/imports` new and show. Villages index links to Import only when `can_import`. Show the imported count and the row errors.
  - [x] Do not add a dashboard widget or a voter-roll import.
- [x] Task 4: Tests (AC: all)
  - [x] Mixed sheet imports the good row and lists the bad rows. Owner and organization are the importer's. A peer does not see the report. A user without `can_import` is rejected. A non-workbook imports nothing.

## Dev Notes

- `creek` is named in the architecture as an alternative. It is not in the Gemfile. Use `roo`, which already is. Do not add a gem.
- Reports stay subtree-owned through `owner_id`. Mock poll stays organization-scoped through `created_by_id`. Do not filter mock-poll imports by subtree.
- Resolve `village` with `organization.villages.find_by(name:)`. Resolve `politician` by name inside the tenant. Vote text is yes, no, or undecided.
- The job must set the tenant before it touches the rows. Run one save per row so a validation failure cannot roll back the file.
- UI: party color on the Import submit button only. The villages index keeps its current header and table.

### References

- [Source: docs/epics.md — Story 3.5, FR31]
- [Source: docs/architecture.md — Ground Reports import flow]
- [Source: docs/project_brief.md — §6.3 reporting agency import]

## Dev Agent Record

### Agent Model Used

Grok 4.7

### Debug Log References

### Completion Notes List

- A role with `can_import` uploads an Excel sheet of reports or mock-poll responses. Good rows save. Each bad row is listed with its spreadsheet row number and the rest of the sheet still imports.
- Reports are owned by the importer, so a peer does not see them. Mock-poll rows are visible across the organization, same as hand entry. Organization and owner columns in the sheet are ignored.
- Import tests passed. Rubocop clean on the new Ruby files. The full suite also reported 28 errors in PR record tests that are outside this story.

### File List

- `db/migrate/20261008050000_add_ground_report_imports.rb` (new)
- `db/schema.rb` (modified)
- `app/models/ground_reports/import.rb` (new)
- `app/services/imports/base_importer.rb` (new)
- `app/services/imports/ground_report_importer.rb` (new)
- `app/services/imports/mock_poll_importer.rb` (new)
- `app/jobs/import_ground_reports_job.rb` (new)
- `app/policies/ground_reports/import_policy.rb` (new)
- `app/controllers/ground_reports/imports_controller.rb` (new)
- `app/controllers/console/roles_controller.rb` (modified)
- `app/views/ground_reports/imports/new.html.erb` (new)
- `app/views/ground_reports/imports/show.html.erb` (new)
- `app/views/ground_reports/villages/index.html.erb` (modified)
- `app/views/console/roles/_form.html.erb` (modified)
- `app/views/console/roles/index.html.erb` (modified)
- `config/routes.rb` (modified)
- `test/services/imports/ground_reports_importer_test.rb` (new)
- `test/integration/ground_reports_import_test.rb` (new)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 3.5 drafted — Excel import for reports and mock poll, row errors, scoped to the importer. Status → ready-for-dev. |
| 2026-10-08 | Story 3.5 implemented — scoped Excel import for reports and mock poll, with per-row errors. Status → review. |

## Status

review
