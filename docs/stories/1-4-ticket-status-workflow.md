---
story_key: 1-4-ticket-status-workflow
epic: 1
depends_on: 1-3-browse-open-tickets
baseline_commit: bcf8ec6151b548ff73a50df480d459d98697d02a
---

# Story 1.4: Ticket status workflow with status-change log

Status: review

## Story

As a user,
I want to move a ticket through its status workflow with each change recorded,
So that the team can see progress and measure resolution time.

## Acceptance Criteria

1. Given an open ticket, when I change its status, then transitions `open` → `in_progress` → `closed`/`blocked` are allowed and shown as the cool `status-pill` (UX-DR5). Disallowed jumps (e.g. `open` → `closed`) are rejected.
2. Each transition writes a Tier-2 `TicketStatusChange` row (from, to, actor, timestamp) — **one row per status change** (FR20, FR53).
3. Time-to-resolution is derivable from the status log and the reported date.

## Tasks / Subtasks

- [x] Task 1: `KitchenCabinet::TicketStatusChange` model + migration — the first Tier-2 log (AC: 2)
  - [x] Migration `create_table :ticket_status_changes` (ticket/organization/actor FK refs, `from_status`, `to_status` null-false, timestamps).
  - [x] Model `KitchenCabinet::TicketStatusChange` (`self.table_name` pinned; `include OrganizationScoped`; `belongs_to :ticket`/`:actor`; `to_status` presence). Append-only; statuses stored as enum string keys.
- [x] Task 2: Ticket transition rules + `change_status!` (AC: 1, 2, 3)
  - [x] `has_many :status_changes`; `TRANSITIONS` map; `may_change_to?`; transactional `change_status!(to:, actor:)` (status + atomic log row, `closed_at` set on →closed); `resolution_duration`.
- [x] Task 3: Route + controller action (AC: 1)
  - [x] Member `patch :status`; `TicketsController#status` via `policy_scope.find` + `authorize :update?`, guarded by `may_change_to?` (illegal → alert, no row).
- [x] Task 4: Authorization (AC: 1)
  - [x] `TicketPolicy#update?` = write ∩ subtree; read-only / out-of-subtree → 404.
- [x] Task 5: Detail-view status control + history (AC: 1, 2)
  - [x] Replaced the Status placeholder with the pill, allowed-next-status `button_to`s (≥44px), and the `status_changes` history (from → to · actor · time); "No changes yet" / "closed" states handled.
- [x] Task 6: Tests + verify (AC: all)
  - [x] `ticket_status_change_test.rb` (isolation release-gate + associations), `ticket_status_workflow_test.rb` (truth table, one-row logging, illegal refused, closed_at + resolution_duration), `kitchen_cabinet_status_test.rb` (advance+log+pill, illegal→no row, read-only→404, out-of-subtree→404).
  - [x] `bin/rails test` → 113 runs / 418 assertions / 0 failures; `bin/rubocop` → 119 files, 0 offenses.

## Dev Notes

- **This introduces the Tier-2 pattern in the concrete.** Story 0.10 established the *concept* (FR53: "lightweight status-transition log, one row per change"); there is **no shared Tier-2 concern** — `TicketStatusChange` is a plain append-only model. Do not reach for PaperTrail/`FullyVersioned` (that's Tier-1, for PII/edit history — not this). Keep it lightweight: a row records who moved the ticket from X to Y and when.
- **Transition integrity is the point.** Enforce the allowed-transitions map in the **model** (`may_change_to?` + `change_status!`), not just by hiding buttons. The status change + the log row must be **atomic** (one transaction) so a transition can never be recorded without its log row, nor vice-versa.
- **Reuse, don't reinvent:**
  - Status enum already exists on `Ticket` (`open/in_progress/closed/blocked`); don't redefine it.
  - `ui/status_pill` renders the pill (label+dot, never color-only, UX-DR5/DR7) — reuse via `render "ui/status_pill", status: ...`.
  - Isolation test helpers: `test/support/tenant_isolation.rb` (`assert_tenant_isolated`, `assert_raises_without_tenant`) — mandatory for the new `TicketStatusChange` tenant model.
  - Authorization + 404 convention: Pundit `update?` + `rescue_from Pundit::NotAuthorizedError → 404` (no 403s).
- **Namespaced-model gotchas (learned in 1.2/1.3):** pin `self.table_name`; set `belongs_to` `class_name:` explicitly; if a form/`button_to` ever wraps the model, watch the param key (not an issue here — the status action takes a simple `to_status` param, not a model-scoped form).
- **Scope boundary (do NOT build):** the **2-step closure + voter-sentiment capture** is Story 1.7 — it will *wrap* the `→ closed` transition with the voter match + sentiment picker. 1.4 only does the generic status move + log (moving to `closed` here just sets `closed_at`). Follow-up log is 1.5; voter-ID gating is 1.6; export/widget is 1.8.
- **UX:** transitions surface as the cool `status-pill`; action buttons are ≥44px (UX-DR9/DR14); the history reads newest-last or newest-first consistently (pick oldest-first so progress reads top-to-bottom).

### Project Structure Notes

- New model: `app/models/kitchen_cabinet/ticket_status_change.rb` (architecture §Project Structure line 274).
- Migration: `db/migrate/<ts>_create_ticket_status_changes.rb`.
- Modify: `app/models/kitchen_cabinet/ticket.rb` (assoc + transitions), `app/controllers/kitchen_cabinet/tickets_controller.rb` (`status`), `app/policies/kitchen_cabinet/ticket_policy.rb` (`update?`), `config/routes.rb` (member `:status`), `app/views/kitchen_cabinet/tickets/show.html.erb` (status control + history).

### References

- [Source: docs/epics.md#Story-1.4] — AC (BDD); FR20 (line 46), FR53 (line 95), UX-DR5.
- [Source: docs/project_brief.md §6.1 / §7a] — status enum; `TicketStatusChange` as the Tier-2 confirmed log.
- [Source: docs/architecture.md#Project-Structure] — `kitchen_cabinet/ (…, ticket_status_change)` (line 274).
- [Source: app/models/kitchen_cabinet/ticket.rb] — existing status enum, `SoftDeletable`, namespaced-model/table-name pattern.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — `show?`/Scope subtree pattern to extend with `update?`.
- [Source: app/views/kitchen_cabinet/tickets/show.html.erb] — the Status placeholder block (lines ~48-55) to replace.
- [Source: app/models/concerns/organization_scoped.rb] + [test/support/tenant_isolation.rb] — tenant model + mandatory isolation test.
- [Source: docs/stories/1-3-browse-open-tickets.md] — `policy_scope` find + 404 convention; namespaced-model lessons.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails db:migrate` → `ticket_status_changes` created cleanly.
- `bin/rails test` → 113 runs, 418 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 119 files, 0 offenses.

### Completion Notes List

- **First concrete Tier-2 log.** `TicketStatusChange` is a plain append-only, org-scoped model (not PaperTrail/Tier-1), with its own release-gate isolation test.
- **Atomic transition + log.** `change_status!` wraps the status update and the log-row insert in one transaction (FR53: one row per change). Transition legality lives in the model (`TRANSITIONS` + `may_change_to?`), enforced regardless of client input; the controller also guards and the view only renders legal buttons.
- **Workflow:** `open → in_progress → closed/blocked` + `blocked → in_progress` (resume); `closed` terminal. →closed sets `closed_at`; `resolution_duration` makes time-to-resolution derivable (AC 3).
- **Authorization:** `update?` = KC write ∩ ticket in viewer subtree; read-only / out-of-subtree → 404.
- **Scope boundary:** →closed here is the plain move; the 2-step closure + voter-sentiment (1.7) will wrap it. Follow-up log (1.5), voter-ID gating (1.6), export/widget (1.8) untouched.

### File List

- `db/migrate/20261006140000_create_ticket_status_changes.rb` (new)
- `db/schema.rb` (modified — ticket_status_changes)
- `app/models/kitchen_cabinet/ticket_status_change.rb` (new)
- `app/models/kitchen_cabinet/ticket.rb` (modified — status_changes assoc, TRANSITIONS, change_status!, resolution_duration)
- `app/policies/kitchen_cabinet/ticket_policy.rb` (modified — update?)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (modified — status action)
- `config/routes.rb` (modified — member patch :status)
- `app/views/kitchen_cabinet/tickets/show.html.erb` (modified — status control + history)
- `test/models/kitchen_cabinet/ticket_status_change_test.rb` (new)
- `test/models/kitchen_cabinet/ticket_status_workflow_test.rb` (new)
- `test/integration/kitchen_cabinet_status_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.4 drafted (BMad create-story) — ticket status workflow with transition guards + atomic Tier-2 `TicketStatusChange` log, detail-view status control + history, derivable time-to-resolution. Status → ready-for-dev. |
| 2026-10-06 | Story 1.4 implemented (BMad dev-story) — `TicketStatusChange` (first Tier-2 log, isolation-tested), `Ticket` TRANSITIONS + atomic `change_status!` + `resolution_duration`, write∩subtree-gated `status` action + route, detail status control + history. 12 new tests; full suite 113/0, rubocop clean. Status → review. |

## Status

review
