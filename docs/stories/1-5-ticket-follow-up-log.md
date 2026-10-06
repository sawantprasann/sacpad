---
story_key: 1-5-ticket-follow-up-log
epic: 1
depends_on: 1-4-ticket-status-workflow
baseline_commit: 22fe2924feca8c5e89fbc76c1d65bd63c930a9f5
---

# Story 1.5: Per-ticket follow-up action log

Status: review

## Story

As a user with Kitchen Cabinet write access,
I want to add running follow-up notes to a ticket,
So that there is a record of what was actually done about the issue.

## Acceptance Criteria

1. Given a ticket, when I add a follow-up entry, then a `TicketFollowUp` row is created (note, created_by, created_at, optional attachment) and entries accumulate **newest-first** (FR23, UX-DR13).
2. Any role with Kitchen Cabinet `write` can add one — **no extra capability** needed.
3. The follow-up log is **visually distinct** from the bare status-change history.

## Tasks / Subtasks

- [x] Task 1: `KitchenCabinet::TicketFollowUp` model + migration (AC: 1)
  - [x] Migration `create_table :ticket_follow_ups` (ticket/organization/created_by FK refs, `note` null-false, timestamps).
  - [x] Model `KitchenCabinet::TicketFollowUp` (`self.table_name` pinned; `include OrganizationScoped`; `belongs_to :ticket`/`:created_by`; `has_one_attached :attachment`; `note` presence). Append-only.
- [x] Task 2: Ticket association (AC: 1)
  - [x] `has_many :follow_ups, class_name: "KitchenCabinet::TicketFollowUp", dependent: :destroy`.
- [x] Task 3: Nested route + controller (AC: 1, 2)
  - [x] Nested `resources :follow_ups, only: :create`; `KitchenCabinet::FollowUpsController#create` via `policy_scope.find` + `authorize :update?` (reuses the ticket gate — no extra capability), `created_by = current_user`, redirect with notice / alert on blank note.
  - [x] Strong params permit only `note`, `attachment`.
- [x] Task 4: Detail-view follow-up log + add form (AC: 1, 3)
  - [x] Replaced the side placeholder with a main-column, card-per-entry log (visually distinct from the compact status History).
  - [x] Add-note form shown only when `policy(@ticket).update?`; `scope: :ticket_follow_up`, `multipart: true`, ≥44px targets.
  - [x] Entries `order(created_at: :desc)` (newest-first) with author/time/note + attachment preview; empty-state handled.
- [x] Task 5: Tests + verify (AC: all)
  - [x] `ticket_follow_up_test.rb` (isolation release-gate, associations, note presence, attachment), `kitchen_cabinet_follow_ups_test.rb` (add with attachment + created_by from session, newest-first render, blank-note no row, read-only → 404, out-of-subtree → 404).
  - [x] `bin/rails test` → 123 runs / 444 assertions / 0 failures; `bin/rubocop` → 124 files, 0 offenses.

## Dev Notes

- **This is the 1.4 pattern again, minus the state machine.** `TicketFollowUp` is another append-only, org-scoped child of `Ticket` — model it exactly like `TicketStatusChange` (namespaced, `self.table_name` pinned, `include OrganizationScoped`, isolation-tested), but with a free-text `note` + optional Active Storage `attachment` instead of from/to statuses. Do **not** invent a new authorization capability — AC 2 is explicit that KC `write` is sufficient; reuse the ticket's `update?` policy (write ∩ subtree).
- **Reuse, don't reinvent:**
  - Nesting + policy: `policy_scope(KitchenCabinet::Ticket).find(params[:ticket_id])` then `authorize @ticket, :update?` — same guard as the status action (Story 1.4). Out-of-subtree/other-org → 404 via `policy_scope`; read-only → 404 via Pundit.
  - Attachments: Active Storage `has_one_attached` (as on `Ticket`/`User`); form needs `multipart: true`.
  - Namespaced-model form param: set `scope: :ticket_follow_up` on `form_with` so params arrive as `ticket_follow_up[...]` matching `require(:ticket_follow_up)` (the 1.2 lesson — `form_with model:` on a `KitchenCabinet::` model would otherwise nest under `kitchen_cabinet_ticket_follow_up`).
  - Isolation helpers: `test/support/tenant_isolation.rb` — mandatory for the new tenant model.
- **UX (UX-DR13):** the follow-up log is append-only, timestamped, attributed, optional-attachment, **newest-first**, and **visually distinct** from the status-change history (which stays a compact list in the Status card). Give follow-ups their own prominent card with per-entry blocks (author + time header, note body, attachment). ≥44px targets (UX-DR9/DR14).
- **Scope boundary (do NOT build):** voter-ID gating (1.6), 2-step closure + sentiment (1.7), export/widget (1.8). Follow-ups are independent of status — any KC-write user can add one at any status (including closed); do not couple them to the workflow.

### Project Structure Notes

- New model: `app/models/kitchen_cabinet/ticket_follow_up.rb`; migration `db/migrate/<ts>_create_ticket_follow_ups.rb`.
- New controller: `app/controllers/kitchen_cabinet/follow_ups_controller.rb`.
- Modify: `app/models/kitchen_cabinet/ticket.rb` (assoc), `config/routes.rb` (nested `follow_ups`), `app/views/kitchen_cabinet/tickets/show.html.erb` (log + form, remove placeholder).

### References

- [Source: docs/epics.md#Story-1.5] — AC (BDD); FR23 (line 49), UX-DR13 (line 178).
- [Source: docs/project_brief.md §6.1] — `TicketFollowUp` (ticket_id, note, created_by_id, created_at).
- [Source: docs/architecture.md] — `kitchen_cabinet/` models + `resources :follow_ups, only: %i[create]` nested route (line 350).
- [Source: app/models/kitchen_cabinet/ticket_status_change.rb] — the append-only, org-scoped child-model pattern to mirror.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — reuse `update?` (write ∩ subtree); no new capability.
- [Source: app/controllers/kitchen_cabinet/tickets_controller.rb] — `require_kitchen_cabinet_access`, `policy_scope.find`, 404 convention.
- [Source: app/views/kitchen_cabinet/tickets/show.html.erb] — the "Follow-up log" placeholder to replace; status History for the "visually distinct" contrast.
- [Source: docs/stories/1-2-log-a-ticket.md] — `scope:`/`multipart:` form lesson; `fixture_file_upload` (`test/fixtures/files/photo.png`).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails db:migrate` → `ticket_follow_ups` created cleanly.
- `bin/rails test` → 123 runs, 444 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 124 files, 0 offenses.

### Completion Notes List

- **Same append-only, org-scoped child pattern as 1.4**, minus the state machine: `TicketFollowUp` carries a free-text `note` + optional Active Storage `attachment`, with its own release-gate isolation test.
- **No new capability** (AC 2): the nested `follow_ups#create` reuses the ticket's `update?` policy (KC write ∩ subtree). Read-only → 404 (Pundit); out-of-subtree/other-org → 404 (`policy_scope.find`). `created_by`/`organization_id` are never from params.
- **Namespaced-form lesson applied:** `scope: :ticket_follow_up` + `multipart: true` so params arrive as `ticket_follow_up[...]` matching `require(:ticket_follow_up)`.
- **UX (UX-DR13):** follow-ups live in their own prominent main-column card (card-per-entry, newest-first, author + time + note + attachment) — visually distinct from the compact status-change History in the Status card. The add form shows only to users who pass `policy(@ticket).update?`.
- Decoupled from status: a follow-up can be added at any status (no workflow coupling).
- Scope boundary: voter-ID gating (1.6), closure + sentiment (1.7), export/widget (1.8) untouched.

### File List

- `db/migrate/20261006150000_create_ticket_follow_ups.rb` (new)
- `db/schema.rb` (modified — ticket_follow_ups)
- `app/models/kitchen_cabinet/ticket_follow_up.rb` (new)
- `app/models/kitchen_cabinet/ticket.rb` (modified — follow_ups assoc)
- `app/controllers/kitchen_cabinet/follow_ups_controller.rb` (new)
- `config/routes.rb` (modified — nested follow_ups)
- `app/views/kitchen_cabinet/tickets/show.html.erb` (modified — follow-up log + form, placeholder removed)
- `test/models/kitchen_cabinet/ticket_follow_up_test.rb` (new)
- `test/integration/kitchen_cabinet_follow_ups_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.5 drafted (BMad create-story) — append-only per-ticket follow-up log (note + optional attachment), nested create gated on KC write ∩ subtree (no extra capability), newest-first detail-view log distinct from status history. Status → ready-for-dev. |
| 2026-10-06 | Story 1.5 implemented (BMad dev-story) — `TicketFollowUp` (isolation-tested), nested `follow_ups#create` reusing the ticket `update?` gate, main-column newest-first log + attachment form. 10 new tests; full suite 123/0, rubocop clean. Status → review. |

## Status

review
