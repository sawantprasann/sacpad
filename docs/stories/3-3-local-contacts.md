---
story_key: 3-3-local-contacts
epic: 3
depends_on: 3-2-worship-yatra-political-position
baseline_commit: f70475e28d4abf2143155c23bed786fdc30017c3
---

# Story 3.3: Local contacts (non-system people)

Status: review

## Story

As a user with Ground Reports access,
I want to record village karyakartas and administrative contacts who aren't system users,
so that local contact info is captured without creating logins.

## Acceptance Criteria

1. Given a village in the organization's constituency, a user with Ground Reports write access can add `VillageLocalKaryakarta` rows (`name`, `phone`, `notes`) and `VillageLocalAdminContact` rows (`name`, free-text `role_title`, `phone`, `notes`). Both are keyed by `village_id` and `organization_id` (FR29).
2. Neither table is a `User` row and neither has a `user_id`. Adding a contact does not create a login.
3. A posted organization id is ignored. A village outside the constituency is rejected. Another organization's contacts for the same village are not visible. Read-only users can see the lists and cannot change them.

## Tasks / Subtasks

- [x] Task 1: Models (AC: 1, 2, 3)
  - [x] `village_local_karyakartas` and `village_local_admin_contacts`. Namespaced models with pinned table names. `OrganizationScoped` and `SoftDeletable`.
  - [x] No `user_id`. Village must be inside the organization's constituency.
  - [x] `role_title` is free text, not an enum.
- [x] Task 2: Village page sections (AC: 1, 3)
  - [x] Nested create routes under the village. Two cards on the village show page. Read-only users see the records without the forms.
  - [x] Keep reports, worship places, yatra, and political history. Do not add mock poll, import, or a dashboard widget.
- [x] Task 3: Tests (AC: all)
  - [x] Model: both kinds save, role title is free text, outside village rejected, no `user_id` column.
  - [x] Integration: writer adds both and `User` count stays the same; reader cannot post; outside village is 404; other org's contact is hidden.

## Dev Notes

- These are org-scoped village facts, like worship places, not subtree-owned reports. Do not add `owner_id`.
- Load the village with `current_user.organization.villages.find`. Set `organization` from the session before save. Never permit `organization_id`.
- Forms must pass `scope: :village_local_karyakarta` and `scope: :village_local_admin_contact` so params do not nest under the namespaced class name.
- UI: two more cards in the existing village-page grid. Party color on the save buttons only.

### References

- [Source: docs/epics.md — Story 3.3, FR29]
- [Source: docs/project_brief.md — §6.3 Local Contacts, decision 31]

## Dev Agent Record

### Agent Model Used

Grok 4.7

### Debug Log References

### Completion Notes List

- Karyakartas and administrative contacts are two lists on the village page. Role is free text. Adding either does not create a `User`.
- Rows are organization-scoped. A posted `organization_id` is not permitted. Another organization's contact on the same village stays hidden.
- Full suite 196 runs, 893 assertions, 0 failures. Rubocop clean on the new Ruby files.

### File List

- `db/migrate/20261008030000_create_village_local_contacts.rb` (new)
- `db/schema.rb` (modified)
- `app/models/ground_reports/village_local_karyakarta.rb` (new)
- `app/models/ground_reports/village_local_admin_contact.rb` (new)
- `app/models/village.rb` (modified)
- `app/policies/ground_reports/village_local_karyakarta_policy.rb` (new)
- `app/policies/ground_reports/village_local_admin_contact_policy.rb` (new)
- `app/controllers/ground_reports/local_karyakartas_controller.rb` (new)
- `app/controllers/ground_reports/local_admin_contacts_controller.rb` (new)
- `app/controllers/ground_reports/villages_controller.rb` (modified)
- `app/views/ground_reports/villages/show.html.erb` (modified)
- `config/routes.rb` (modified)
- `test/models/ground_reports/village_contacts_test.rb` (new)
- `test/integration/ground_reports_test.rb` (modified)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 3.3 drafted — village karyakartas and administrative contacts, neither a system user. Status → ready-for-dev. |
| 2026-10-08 | Story 3.3 implemented — karyakarta and administrative-contact lists on the village page. Full suite 196/0, rubocop clean. Status → review. |

## Status

review
