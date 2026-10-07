---
story_key: 3-2-worship-yatra-political-position
epic: 3
depends_on: 3-1-village-report-testimonials
baseline_commit: f70475e28d4abf2143155c23bed786fdc30017c3
---

# Story 3.2: Worship places, yatra note, and political position

Status: review

## Story

As a user with Ground Reports access,
I want to maintain a village's worship places, a single yatra note, and its ruling-party history,
so that durable village facts are tracked correctly.

## Acceptance Criteria

1. Given a village in the organization's constituency, a user with Ground Reports write access can add `WorshipPlace` rows. The type is free text, not limited to temples (FR28).
2. `VillageYatra` is exactly one editable note per village per organization, enforced by a unique index on `(village_id, organization_id)` (FR28). Saving again updates that row.
3. `VillagePoliticalPosition` keeps history: party from the Party catalog, representative, title, started, and ended. At most one row per village per organization has a blank end date (FR28). Opening a new current position closes the previous one.
4. All three carry `village_id` and `organization_id`. A posted organization id is ignored. A village outside the constituency is rejected. Another organization's rows for the same village are not visible. Read-only users can see the sections and cannot change them.

## Tasks / Subtasks

- [x] Task 1: Models (AC: 1, 2, 3, 4)
  - [x] `worship_places`, `village_yatras`, `village_political_positions`. Namespaced models with pinned table names. `OrganizationScoped`.
  - [x] Worship `place_type` is a string. Do not use a column named `type` (Rails treats that as single-table inheritance).
  - [x] Yatra unique index on `(village_id, organization_id)`. Notes are a text area. `updated_by` is the user who last saved.
  - [x] Position `party_id` FK. Partial unique index for one open row (`ended_at` null) per village and organization. Creating a new open row sets `ended_at` on the previous open row.
- [x] Task 2: Village page sections (AC: 1, 2, 3, 4)
  - [x] Nested routes under the village. Forms on the village show page. Read-only users see the records without the forms.
  - [x] Keep the report list. Do not add contacts, mock poll, import, or a dashboard widget.
- [x] Task 3: Tests (AC: all)
  - [x] Model: any place type, second yatra rejected, second org can have its own yatra, new current position closes the previous one.
  - [x] Integration: writer saves all three; reader cannot post; outside village is 404; other org's place is hidden.

## Dev Notes

- Village facts are org-scoped, not subtree-owned. Reports stay subtree-scoped. Do not filter worship, yatra, or position by `owner_id`.
- Load the village with `current_user.organization.villages.find`. Set `organization` from the session before save.
- Party catalog is global (`Party`). The select lists `Party.order(:name)`.
- UI: these sections sit under the report table as separate cards. Party color on the save buttons only.

### References

- [Source: docs/epics.md — Story 3.2, FR28]
- [Source: docs/project_brief.md — WorshipPlace, VillageYatra, VillagePoliticalPosition]
- [Source: app/models/party_membership.rb — history row with a nullable end]

## Dev Agent Record

### Agent Model Used

Grok 4.7

### Debug Log References

### Completion Notes List

- Worship places, one yatra note, and political history sit on the village page under the report list. Type is free text (`place_type`). A new current position closes the previous open row.
- Rows are organization-scoped, not subtree-owned. A posted `organization_id` is not permitted. Another organization's place on the same village stays hidden.
- Full suite 193 runs, 861 assertions, 0 failures. Rubocop clean on the new Ruby files.

### File List

- `db/migrate/20261008020000_create_village_facts.rb` (new)
- `db/schema.rb` (modified)
- `app/models/concerns/village_in_constituency.rb` (new)
- `app/models/ground_reports/worship_place.rb` (new)
- `app/models/ground_reports/village_yatra.rb` (new)
- `app/models/ground_reports/village_political_position.rb` (new)
- `app/models/village.rb` (modified)
- `app/policies/ground_reports/worship_place_policy.rb` (new)
- `app/policies/ground_reports/village_yatra_policy.rb` (new)
- `app/policies/ground_reports/village_political_position_policy.rb` (new)
- `app/controllers/ground_reports/loads_village.rb` (new)
- `app/controllers/ground_reports/worship_places_controller.rb` (new)
- `app/controllers/ground_reports/yatra_controller.rb` (new)
- `app/controllers/ground_reports/political_positions_controller.rb` (new)
- `app/controllers/ground_reports/villages_controller.rb` (modified)
- `app/views/ground_reports/villages/show.html.erb` (modified)
- `config/routes.rb` (modified)
- `test/models/ground_reports/village_facts_test.rb` (new)
- `test/integration/ground_reports_test.rb` (modified)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 3.2 drafted — worship places, one yatra note per village per org, political-position history. Status → ready-for-dev. |
| 2026-10-08 | Story 3.2 implemented — worship places, one yatra note, political-position history on the village page. Full suite 193/0, rubocop clean. Status → review. |

## Status

review
