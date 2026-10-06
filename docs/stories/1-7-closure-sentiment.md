---
story_key: 1-7-closure-sentiment
epic: 1
depends_on: 1-6-voter-id-gate
baseline_commit: 7111acd14fd57d8f7ca3538ce755323d00b857c8
---

# Story 1.7: Two-step closure with voter-sentiment capture

Status: review

## Story

As a user closing a resolved ticket,
I want to attach the voter and record how they feel,
So that resolution feeds the constituency's voter-sentiment picture.

## Acceptance Criteria

1. Given a ticket being closed, when I complete the closure flow, then step one confirms resolution + closure date; step two optionally matches a `Voter` (from this org's roll) and shows the 3-segment `sentiment-picker` (UX-DR12).
2. Choosing pleased/transit/displeased writes `sentiment_status` (+ `sentiment_updated_by_id`/`sentiment_updated_at`) to the matched `Voter` (the primitive from Story 0.15) (FR22, FR43).
3. Closing **without** a voter is allowed, and a **"no voter match"** (loose lookup) still allows the close (UX-DR12).
4. A quiet factual confirmation ("on record as help delivered") is shown — **no celebratory animation**.

## Tasks / Subtasks

- [x] Task 1: `Voter#record_sentiment!` helper (AC: 2)
  - [x] `Voter#record_sentiment!(status, by:)` updates `sentiment_status` + `sentiment_updated_by_id` + `sentiment_updated_at`; Tier-1 versioned via `FullyVersioned`. Caller validates `status` against `Voter.sentiment_statuses.keys`.
- [x] Task 2: Nested closure route + controller (AC: 1, 2, 3)
  - [x] `resource :closure, only: %i[new create]` nested under tickets.
  - [x] `KitchenCabinet::ClosuresController` — `set_ticket` (policy_scope.find + `authorize :update?` + `may_change_to?("closed")` guard → alert if not). `create` in a transaction: `change_status!(to: "closed")`, override `closed_at` from `closure_date`, set `voter_id` if given, and `matched_voter.record_sentiment!` when voter + valid sentiment match. Quiet notice on redirect; invalid date rescued.
  - [x] Optional path never hard-fails — missing/unmatched voter still closes.
- [x] Task 3: `sentiment-picker` component (AC: 1, 4)
  - [x] `ui/_sentiment_picker.html.erb` — 3 radio segments (pleased/transit/displeased) with text labels + RAG dot (never colour-alone), optional, ≥44px. No Stimulus (radios submit natively; architecture's sentiment-picker Stimulus deferred).
- [x] Task 4: Closure flow view + wire the "Closed" action (AC: 1, 3, 4)
  - [x] `closures/new.html.erb` — Step 1 (confirm + closure_date default today), Step 2 (optional voter_id + sentiment picker), single "Close ticket" submit, mobile-first ≥44px.
  - [x] `show.html.erb` — the `closed` transition now links to the closure flow; `in_progress`/`blocked` keep the direct status `button_to`.
  - [x] Quiet flash confirmation only — no animation.
- [x] Task 5: Tests + verify (AC: all)
  - [x] `voter_sentiment_test.rb` — `record_sentiment!` sets status + updated_by/at + a `VoterVersion`.
  - [x] `kitchen_cabinet_closure_test.rb` — matched voter writes sentiment; no-voter closes w/o sentiment; unmatched voter_id still closes; quiet confirmation copy; open ticket guarded; read-only / out-of-subtree → 404.
  - [x] `bin/rails test` → 139 runs / 489 assertions / 0 failures; `bin/rubocop` → 129 files, 0 offenses.

## Dev Notes

- **This story composes three earlier pieces — do not re-implement them:**
  - **Status → closed** via `Ticket#change_status!(to: "closed", actor:)` (Story 1.4): it already enforces the transition, writes the Tier-2 `TicketStatusChange` row, and sets `closed_at`. The closure flow is a *wrapper* around this, not a replacement — don't hand-roll a status update.
  - **voter_id gate** (Story 1.6): setting `voter_id` only succeeds because the ticket is already `closed` inside the transaction. Order matters — close first, then set `voter_id`.
  - **Voter primitive** (Story 0.15): `sentiment_status` enum (`pleased`/`transit`/`displeased`, `prefix: :sentiment`), `sentiment_updated_by_id`, `sentiment_updated_at`; `include FullyVersioned` means the sentiment write is captured in `VoterVersion` automatically (FR43 history).
- **Two-step = presentation, one POST.** The architecture exposes only `resource :closure, only: %i[new create]`, so implement the "two steps" as two labelled sections on the single `new` page with one `create` submit (not a stateful multi-request wizard). This matches the route and the Minimal-Hotwire posture.
- **Loose lookup, optional everything (AC 3).** `matched_voter` (Story 1.6) is `Voter.find_by(voter_id:)` — org-scoped, deterministic-encryption lookup, **no FK**. If it returns nil, or no `voter_id`/sentiment was entered, the ticket still closes; only skip the sentiment write. Never block a close on voter matching.
- **Transaction integrity.** Wrap close + closed_at + voter_id + sentiment in one `transaction` so a partially-applied closure can't occur. `change_status!` already opens its own transaction; a nesting is fine (savepoints).
- **UX (UX-DR12):** quiet factual confirmation ("on record as help delivered"), **no celebration**; sentiment is a 3-segment picker with text labels (RAG is presentation only, never color-alone — UX-DR4/5/7); ≥44px targets (UX-DR9/DR14).
- **Files being changed:**
  - `app/views/kitchen_cabinet/tickets/show.html.erb` — the Status card's transition buttons (currently all `button_to` to `status`); reroute only the `closed` one to the closure flow.
  - `app/models/voter.rb` — add `record_sentiment!` (keep the encryption/enum as-is).
  - `config/routes.rb` — ticket member block has `patch :status`/`patch :voter` + nested `follow_ups`; add `resource :closure`.
- **Scope boundary (do NOT build):** Kitchen Cabinet dashboard widget + Excel/chart export is Story 1.8 (the sentiment data this story writes feeds the RAG rollup in Epic 7, not here). Do not add reporting/aggregation in 1.7.

### Project Structure Notes

- New: `app/controllers/kitchen_cabinet/closures_controller.rb`, `app/views/kitchen_cabinet/closures/new.html.erb`, `app/views/ui/_sentiment_picker.html.erb`.
- Modify: `app/models/voter.rb`, `config/routes.rb`, `app/views/kitchen_cabinet/tickets/show.html.erb`.
- No migration (ticket `closed_at`/`voter_id` and voter `sentiment_*` columns already exist).

### References

- [Source: docs/epics.md#Story-1.7] — AC (BDD); FR22 (line 48), FR43 (line 79), UX-DR12 (line 177).
- [Source: docs/project_brief.md §6.1 / §6.7] — closure flow, voter-sentiment write on resolution.
- [Source: docs/architecture.md] — `resource :closure, only: %i[new create]` (line ~349); `ui/_sentiment_picker`; sentiment-picker Stimulus optional (lines 157, 201); Voter sentiment write is a 0.15 dependency (line 182).
- [Source: app/models/voter.rb] — `sentiment_status` enum (prefix `:sentiment`), `FullyVersioned`; add `record_sentiment!`.
- [Source: app/models/kitchen_cabinet/ticket.rb] — `change_status!`, `closed_at`, `may_change_to?`, `matched_voter`, voter_id gate.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — reuse `update?` (write ∩ subtree).
- [Source: app/views/kitchen_cabinet/tickets/show.html.erb] — status buttons to rewire; the voter-gate field already renders the unlocked voter_id.
- [Source: docs/stories/1-4-ticket-status-workflow.md] + [1-6-voter-id-gate.md] — the status + gate mechanics this flow composes.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails test` → 139 runs, 489 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 129 files, 0 offenses.
- No migration (ticket `closed_at`/`voter_id` + voter `sentiment_*` columns pre-existed).

### Completion Notes List

- **Composition, not reinvention:** closure calls `Ticket#change_status!(to: "closed")` (1.4 — Tier-2 log + closed_at), then sets `voter_id` (1.6 gate passes because it's now closed), then `Voter#record_sentiment!` (0.15 columns, Tier-1 versioned). Order enforced; all in one transaction.
- **Everything optional (AC 3):** no `voter_id`, or an unmatched `voter_id`, still closes — the sentiment write is skipped (tested both). `matched_voter` is the loose `Voter.find_by(voter_id:)` lookup from 1.6.
- **Two-step = presentation, one POST** — matches `resource :closure, only: [new, create]` + Minimal-Hotwire posture; no stateful wizard.
- **Guard:** closure requires `may_change_to?("closed")` (ticket `in_progress`); an `open` ticket is redirected with an alert. The detail's "Close…" link appears only for in_progress tickets and routes here, not the bare status PATCH.
- **UX-DR12:** quiet "On record as help delivered" flash, no celebration; sentiment picker uses text labels + RAG dot (never colour-alone). No Stimulus.
- Authorization reuses `update?` (write ∩ subtree); read-only / out-of-subtree → 404.
- **Scope boundary:** dashboard widget + export is Story 1.8; the RAG rollup consuming this sentiment is Epic 7 — no reporting here.

### File List

- `app/models/voter.rb` (modified — `record_sentiment!`)
- `app/controllers/kitchen_cabinet/closures_controller.rb` (new)
- `app/views/kitchen_cabinet/closures/new.html.erb` (new — two-step closure form)
- `app/views/ui/_sentiment_picker.html.erb` (new)
- `app/views/kitchen_cabinet/tickets/show.html.erb` (modified — "Close…" routes to closure flow)
- `config/routes.rb` (modified — nested `resource :closure`)
- `test/models/voter_sentiment_test.rb` (new)
- `test/integration/kitchen_cabinet_closure_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.7 drafted (BMad create-story) — two-step closure flow (confirm + date → optional voter match + 3-segment sentiment-picker) composing status→closed (1.4), the voter_id gate (1.6) and the Voter sentiment write (0.15); quiet confirmation, loose/optional voter. No migration. Status → ready-for-dev. |
| 2026-10-06 | Story 1.7 implemented (BMad dev-story) — `Voter#record_sentiment!`, `KitchenCabinet::ClosuresController` (transactional close + closed_at + voter_id + sentiment), `ui/_sentiment_picker`, closure form, "Close…" rewired. 8 new tests; full suite 139/0, rubocop clean. Status → review. |

## Status

review
