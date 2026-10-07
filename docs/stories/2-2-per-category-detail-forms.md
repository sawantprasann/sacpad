---
story_key: 2-2-per-category-detail-forms
epic: 2
depends_on: 2-1-cadre-activity-base-capture
baseline_commit: 597d5ae7d31f9b1d6ae955812cf3381da3a873e2
---

# Story 2.2: Per-category detail forms

Status: review

## Story

As a user,
I want each category to capture its own specific fields,
so that genuinely different activity types aren't forced into one shape.

## Acceptance Criteria

1. Given a chosen category, when the activity is saved, the matching detail row is created and linked by `cadre_activity_id`: `CadreActivityProgram` for Program By Party and Personal Program, `CadreActivityLeadershipMeet`, `CadreActivityPartyProgramHosted`, `CadreActivityPersonalActivity`, or `CadreActivityOneToOne` (FR24).
2. One To One stores `karyakarta_user_id` when the person is a `User` in this organization, or `karyakarta_name_text` when they are not. A user from another organization is rejected (FR25).
3. Each detail table has a unique indexed FK to `cadre_activities`, plus `organization_id` NOT NULL, and passes the tenant-isolation test.
4. The capture form shows only that category's fields, still posts `cadre_activity[...]`, and the show page displays the saved detail. Saving a category without its detail does not persist the activity.

## Tasks / Subtasks

- [x] Task 1: Five detail models + one migration (AC: 1, 2, 3)
  - [x] Tables `cadre_activity_programs`, `cadre_activity_leadership_meets`, `cadre_activity_party_program_hosteds`, `cadre_activity_personal_activities`, `cadre_activity_one_to_ones`. Each: `cadre_activity_id` NOT NULL unique FK, `organization_id` NOT NULL FK, the brief §6.2 columns, timestamps.
  - [x] Namespaced models under `CadreProgram::`, `self.table_name` pinned, `include` a shared detail concern (`OrganizationScoped`, `belongs_to :cadre_activity`). No `FullyVersioned`. No soft-delete columns (the parent is the soft-deleted record).
  - [x] `CadreActivity` `has_one` for each, `accepts_nested_attributes_for` with `reject_if: :all_blank`, and `DETAIL_ASSOCIATIONS` so `program_by_party` and `personal_program` both use `:program`.
  - [x] Before validation, drop a new detail that does not match the category. Require the matching detail. Require each shape's name field (`program_name`, `whom_to_meet`, `program_name`, `activity_name`). One To One requires a same-org user or a fallback name.
- [x] Task 2: Form, show page, strong params (AC: 1, 2, 4)
  - [x] Build detail shells on `new` and on a failed `create` so every fieldset renders. Permit only the detail columns. Never permit `organization_id`, `owner_id`, or `cadre_activity_id`.
  - [x] Alpine `x-model` on the category select. Each fieldset is `x-show` + `:disabled` unless it matches, so hidden inputs are not submitted. Reuse `min-h-11` and the TailAdmin field classes. Karyakarta `<select>` lists only `User` rows in the current organization, with a blank option, plus the fallback name field.
  - [x] Show page renders the saved detail under Media Value. No Excel, no dashboard widget, no edit/delete.
- [x] Task 3: Tests (AC: all)
  - [x] Model: both program categories create `CadreActivityProgram`; the other three categories create their own class; one-to-one accepts a same-org user and a text fallback, and rejects another org's user; each detail model raises with no tenant and is tenant-isolated.
  - [x] Integration: rendered form contains each detail's param name under `cadre_activity[...]`; a leadership post persists only a leadership row; a one-to-one post with a foreign `karyakarta_user_id` is 422; show renders the detail.
  - [x] Update Story 2.1 creates that saved a bare activity (`cadre_activity_test`, `cadre_program_activities_test`) so they include the matching detail. `bin/rails test` and `bin/rubocop` stay green.

## Dev Notes

- **This story fills the base row from 2.1.** Do not add the dashboard widget or Excel export (Story 2.3). Do not add a Console catalog. Categories stay the integer enum already on `CadreActivity`.
- **Two categories, one table.** `program_by_party` and `personal_program` both `has_one :program`. They stay separate enum values.
- **Child rows are tenant data.** The brief's column list omits `organization_id`; the architecture still requires it on every domain table, and `TicketFollowUp` is the precedent. Include `OrganizationScoped`. Copy `organization_id` from the parent as a backup. Do not trust a posted organization id.
- **Do not break 2.1.** After this story, `CadreActivity.create!` without a matching detail is invalid. The existing model and integration creates must pass nested attributes. The list, subtree scope, activity log, sidebar, and photo upload stay as they are.
- **Form scope.** The form is already `scope: :cadre_activity`. Nested fields are `cadre_activity[program_attributes][program_name]` and the same pattern for the other associations. Assert a rendered `name=`, not only a direct POST.
- **Karyakarta list.** `User` is not `acts_as_tenant`. Filter `User.where(organization_id: current_user.organization_id)`. A posted id from another org fails the model validation.
- **Alpine is already on the org layout** (`x-data` / `x-cloak` / `[x-cloak]{display:none}`). Use it to show one fieldset. `:disabled` on the fieldset keeps the other shapes out of the POST. `keep_only_matching_detail` is the server-side backstop if every fieldset is submitted.
- **Columns (brief §6.2).** Program: `program_name`, `occasion`, `location`, `occurred_on` (date), `host`, `notes`. Leadership: `whom_to_meet`, `point_of_discussion`, `work_submitted`, `submitted_on`, `followup_on`, `resolution_notes`. Hosted: `program_name`, `hosted_on`, `location`, `total_attendees` (integer), `print_media`, `electronic_media`. Personal: `activity_name`, `occasion`, `total_submission` (string — the brief does not type it), `from_date`, `to_date`, `notes`. One To One: `karyakarta_user_id` (nullable FK users, indexed), `karyakarta_name_text`, `assignment`, `resolved` (boolean, default false), `from_date`, `to_date`, `notes`.
- **No new gems.** Pinned stack only.

### References

- [Source: docs/epics.md#Story-2.2] — AC, FR24, FR25.
- [Source: docs/project_brief.md §6.2] — five detail shapes; two categories share `CadreActivityProgram`; karyakarta FK plus fallback.
- [Source: docs/stories/2-1-cadre-activity-base-capture.md] — base model, form scope, enum map. Do not redo capture.
- [Source: app/models/kitchen_cabinet/ticket_follow_up.rb] — child model with `OrganizationScoped` and a pinned table name.
- [Source: app/controllers/cadre_program/activities_controller.rb] — `create` to extend with nested params.
- [Source: app/views/cadre_program/activities/new.html.erb] — form to extend. Keep `scope: :cadre_activity`.

## Dev Agent Record

### Agent Model Used

Grok 4.7 (BMad dev-story)

### Debug Log References

- `bin/rails db:migrate` created the five detail tables.
- `bin/rails test` → 167 runs / 0 failures (was 158). `bin/rubocop` → 147 files, 0 offenses.
- Detail isolation re-run after covering all five models: 5 runs, 0 failures.

### Completion Notes List

- Five detail models on the 2.1 base. Program By Party and Personal Program both save `CadreActivityProgram`. The other four categories have their own table.
- One To One accepts a same-organization user or a typed name, and rejects a user from another organization.
- The form shows one fieldset at a time (Alpine). Disabled fieldsets are not submitted, and the model drops a detail that does not match the category.
- Saving a category without its detail does not persist the activity. Story 2.1 creates were updated to include the matching detail.
- No dashboard widget and no Excel export.

### File List

- `db/migrate/20261007110000_create_cadre_activity_details.rb` (new)
- `db/schema.rb` (modified)
- `app/models/cadre_program/activity_detail.rb` (new)
- `app/models/cadre_program/cadre_activity_program.rb` (new)
- `app/models/cadre_program/cadre_activity_leadership_meet.rb` (new)
- `app/models/cadre_program/cadre_activity_party_program_hosted.rb` (new)
- `app/models/cadre_program/cadre_activity_personal_activity.rb` (new)
- `app/models/cadre_program/cadre_activity_one_to_one.rb` (new)
- `app/models/cadre_program/cadre_activity.rb` (modified — has_one details)
- `app/controllers/cadre_program/activities_controller.rb` (modified — nested params)
- `app/views/cadre_program/activities/new.html.erb` (modified)
- `app/views/cadre_program/activities/_detail_fields.html.erb` (new)
- `app/views/cadre_program/activities/show.html.erb` (modified)
- `app/views/cadre_program/activities/_detail.html.erb` (new)
- `test/models/cadre_program/cadre_activity_test.rb` (modified)
- `test/models/cadre_program/cadre_activity_detail_test.rb` (new)
- `test/integration/cadre_program_activities_test.rb` (modified)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-07 | Story 2.2 drafted (BMad create-story) — five detail tables on the 2.1 base, shared program shape, one-to-one karyakarta FK or fallback name. Status → ready-for-dev. |
| 2026-10-07 | Story 2.2 implemented (BMad dev-story) — detail models, category fieldsets, show page, isolation tests. Full suite 167/0, rubocop clean. Status → review. |

## Status

review
