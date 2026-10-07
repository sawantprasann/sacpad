---
story_key: 3-4-mock-poll-capture-tally
epic: 3
depends_on: 3-3-local-contacts
baseline_commit: f70475e28d4abf2143155c23bed786fdc30017c3
---

# Story 3.4: Mock poll capture and read-time tally

Status: review

## Story

As a user with Ground Reports access,
I want to capture village survey responses and see who's likely to win,
so that polling informs strategy without a separate tally table.

## Acceptance Criteria

1. Given a village in the organization's constituency, a user with Ground Reports write access can record `MockPollResponse` rows: one per respondent per politician. Each row has a politician from this organization's roster, `preference_basis` of individual or party, `vote_intent` of yes, no, or undecided, an optional mobile and note, and `created_by` (FR30).
2. Win-likelihood is computed when the village page loads by grouping responses for that village by politician and vote intent. The politician with the most yes votes is marked likely to win. Ties share that mark. No tally table is stored (FR30).
3. A posted organization id is ignored. A village outside the constituency is rejected. A politician from another organization is rejected. Another organization's responses are not visible. Read-only users can see the tally and cannot record a response.

## Tasks / Subtasks

- [x] Task 1: Model (AC: 1, 2, 3)
  - [x] `mock_poll_responses`. Namespaced model, pinned table name, `OrganizationScoped`, `SoftDeletable`.
  - [x] `vote_intent` is a nullable boolean (`true` yes, `false` no, `nil` undecided). `preference_basis` is an enum. No `mock_poll_tallies` table.
  - [x] `tally_for` groups on read. Village must be in the constituency. Politician must belong to the same organization.
- [x] Task 2: Village page (AC: 1, 2, 3)
  - [x] Nested create route. Full-width card under the other village sections: tally, response list, and a form when the user can write and the org has politicians.
  - [x] Do not add Excel import or a dashboard widget.
- [x] Task 3: Tests (AC: all)
  - [x] Model: yes/no/undecided, both preference bases, tally counts, tie, outside village, other-org politician, no tally table.
  - [x] Integration: writer records responses and sees the likely winner; reader cannot post; outside village is 404; other org's respondent is hidden.

## Dev Notes

- Excel import is Story 3.5. This story is hand entry plus the live tally only.
- `created_by` is who recorded the row. Do not add `owner_id`, and do not filter responses by subtree.
- Load the village with `current_user.organization.villages.find`. Set `organization` and `created_by` from the session. Never permit `organization_id` or `created_by_id`.
- The form uses `scope: :mock_poll_response` and a `vote_choice` of yes/no/undecided so the boolean column can store undecided as nil.
- Politicians are the org roster (`Politician`), not free text. If the roster is empty, say so and do not show the form.
- UI: white card, gray tally table. Party color on the record button only. "Likely" uses the same green badge as a current political position.

### References

- [Source: docs/epics.md — Story 3.4, FR30]
- [Source: docs/project_brief.md — §6.3 Mock Poll]

## Dev Agent Record

### Agent Model Used

Grok 4.7

### Debug Log References

### Completion Notes List

- A village page records one survey row per respondent per politician. Vote is yes, no, or undecided. Leaning is the person or the party.
- "Likely to win" is the politician with the most yes votes, counted when the page loads. A tie lists everyone tied. No tally table is stored.
- Full suite 200 runs, 926 assertions, 0 failures. Rubocop clean on the new Ruby files.

### File List

- `db/migrate/20261008040000_create_mock_poll_responses.rb` (new)
- `db/schema.rb` (modified)
- `app/models/ground_reports/mock_poll_response.rb` (new)
- `app/models/village.rb` (modified)
- `app/policies/ground_reports/mock_poll_response_policy.rb` (new)
- `app/controllers/ground_reports/mock_poll_responses_controller.rb` (new)
- `app/controllers/ground_reports/villages_controller.rb` (modified)
- `app/views/ground_reports/villages/show.html.erb` (modified)
- `config/routes.rb` (modified)
- `test/models/ground_reports/mock_poll_response_test.rb` (new)
- `test/integration/ground_reports_test.rb` (modified)
- `docs/stories/sprint-status.yaml` (modified)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 3.4 drafted — mock poll responses and a tally computed on read. Import stays in 3.5. Status → ready-for-dev. |
| 2026-10-08 | Story 3.4 implemented — mock poll capture and a live yes-vote tally on the village page. Full suite 200/0, rubocop clean. Status → review. |

## Status

review
