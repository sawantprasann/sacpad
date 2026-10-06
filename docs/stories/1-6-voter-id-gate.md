---
story_key: 1-6-voter-id-gate
epic: 1
depends_on: 1-5-ticket-follow-up-log
baseline_commit: eebdaaf5519e1c75197ed245eb0018a0b8d871dd
---

# Story 1.6: Voter-ID capture gated on resolution

Status: review

## Story

As the system,
I want to prevent a voter ID from being attached until a ticket is closed,
So that a voter ID on file always means help was actually delivered.

## Acceptance Criteria

1. Given a ticket not yet closed, when a user tries to set `voter_id`, then the `voter-gate-field` is shown but **locked** (disabled + lock glyph + helper "Voter ID unlocks once this issue is closed"), and a **model-level validation** rejects any persist attempt (FR21, UX-DR11).
2. Once `status == closed` the field **unlocks** and `voter_id` can be set/updated (FR21).
3. `voter_id` is a **loose lookup** to `Voter.voter_id` — not an enforced FK.

## Tasks / Subtasks

- [x] Task 1: Model-level gate on `KitchenCabinet::Ticket` (AC: 1, 2, 3)
  - [x] `validate :voter_id_locked_until_closed` (error on `:voter_id` when `voter_id.present? && !closed?`) — rejects any persist while unresolved; validates once closed. No migration (column exists).
  - [x] `matched_voter` loose-lookup helper (`Voter.find_by(voter_id:)`, deterministic encryption, org-scoped; nil when none; no FK).
- [x] Task 2: Route + controller action (AC: 1, 2)
  - [x] Member `patch :voter`; `TicketsController#voter` via `policy_scope.find` + `authorize :update?`, `update(voter_id:)` with model as the authority (notice / model-error alert). Out-of-subtree/read-only → 404.
- [x] Task 3: `voter-gate-field` component (AC: 1, 2, 3)
  - [x] `app/views/ui/_voter_gate_field.html.erb` — editable form when closed + permitted (with matched-voter / loose-lookup note), disabled+lock+helper when not closed, read-only disabled when closed-but-not-permitted; normal (not error) styling, ≥44px.
  - [x] Replaced the Voter ID placeholder card body with `render "ui/voter_gate_field"`.
  - [x] No Stimulus — lock/unlock is server-side off `status`; architecture's voter-gate Stimulus deferred (no speculative JS).
- [x] Task 4: Tests + verify (AC: all)
  - [x] Model `ticket_voter_gate_test.rb`: voter_id invalid+unpersisted while open, valid+persisted once closed, `matched_voter` loose lookup (nil → Voter).
  - [x] Integration `kitchen_cabinet_voter_gate_test.rb`: save on closed, rejected on open, locked vs editable render, read-only → 404, out-of-subtree → 404.
  - [x] `bin/rails test` → 131 runs / 465 assertions / 0 failures; `bin/rubocop` → 126 files, 0 offenses.

## Dev Notes

- **The gate is a model invariant, not UI.** AC 1 explicitly requires a model-level validation — the disabled field is only a convenience. Enforce `voter_id.present? && !closed?` ⇒ invalid in the model so a crafted request can never attach a voter id to an unresolved ticket. The business meaning (brief §6.1): a `voter_id` on file is a guarantee that help was delivered.
- **Loose lookup, deliberately.** `voter_id` stays a plain string column with **no** FK and **no** `belongs_to :voter`. Use `Voter.find_by(voter_id:)` for display only; a value with no matching `Voter` is valid (AC 3). `Voter#voter_id` is deterministically encrypted (Story 0.15), which is exactly why `find_by` works.
- **Reuse, don't reinvent:**
  - Authorization/404: reuse the ticket `update?` policy + `policy_scope(...).find` (Stories 1.3/1.4) — same guard as status/follow-ups.
  - `closed?` comes from the existing `status` enum; the only way to reach `closed` is the Story 1.4 workflow (`in_progress → closed`).
  - View helpers `ta_field_classes`/`ta_btn_secondary`; `policy(ticket)` is available in views (Pundit helper).
- **Current state of the files being changed:**
  - `app/views/kitchen_cabinet/tickets/show.html.erb` — the side "Voter ID" card currently shows the value + a "later story" note (lines ~126-131). Replace its body with the gate component; keep the card heading.
  - `app/models/kitchen_cabinet/ticket.rb` — has the `status` enum + `closed?`, `change_status!` (1.4), and the `voter_id` column (1.2). Add the validation + helper; **do not** touch the status machine.
  - `app/controllers/kitchen_cabinet/tickets_controller.rb` — has `index/show/new/create/status`; add `voter`.
  - `config/routes.rb` — ticket member block currently has `patch :status` + nested `follow_ups`; add `patch :voter`.
- **UX-DR11:** always-visible, locked unless closed, **normal (not error) styling**, lock glyph + the exact helper copy "Voter ID unlocks once this issue is closed". ≥44px targets (UX-DR9/DR14).
- **Scope boundary (do NOT build):** the **2-step closure flow + voter-sentiment picker** is Story 1.7 — it will match a `Voter` and write `sentiment_status` during closing. 1.6 only unlocks/validates the `voter_id` field on an already-closed ticket. Export/widget is 1.8. Do not add sentiment capture here.

### Project Structure Notes

- Modify: `app/models/kitchen_cabinet/ticket.rb`, `app/controllers/kitchen_cabinet/tickets_controller.rb`, `config/routes.rb`, `app/views/kitchen_cabinet/tickets/show.html.erb`.
- New: `app/views/ui/_voter_gate_field.html.erb` (architecture §Project Structure line 305).
- No migration, no new model.

### References

- [Source: docs/epics.md#Story-1.6] — AC (BDD); FR21 (line 47), UX-DR11 (line 176).
- [Source: docs/project_brief.md §6.1] — `voter_id` settable only once status=closed; loose lookup to `Voter`, not a FK.
- [Source: docs/architecture.md] — `ui/_voter_gate_field` (line 305); Minimal-Hotwire posture / voter-gate Stimulus is optional (lines 157, 201).
- [Source: app/models/voter.rb] — `encrypts :voter_id, deterministic: true` (why `find_by` works); org-scoped.
- [Source: app/models/kitchen_cabinet/ticket.rb] — `status` enum/`closed?`, `voter_id` column, `change_status!`.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — reuse `update?` (write ∩ subtree).
- [Source: app/views/kitchen_cabinet/tickets/show.html.erb] — the Voter ID placeholder card to replace.
- [Source: docs/stories/1-4-ticket-status-workflow.md] — `status`/member-route + `update?` pattern this story mirrors.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (BMad dev-story)

### Debug Log References

- `bin/rails test` → 131 runs, 465 assertions, 0 failures, 0 errors.
- `bin/rubocop` → 126 files, 0 offenses.
- No migration (the `voter_id` column shipped in Story 1.2).

### Completion Notes List

- **Gate is a model invariant** (`voter_id_locked_until_closed`), not UI: a crafted PATCH to set `voter_id` on an unresolved ticket simply fails validation and does not persist (proven in both model + integration tests). The disabled field is convenience only.
- **Loose lookup, no FK:** `matched_voter` uses `Voter.find_by(voter_id:)` (deterministic encryption from Story 0.15 makes this queryable), org-scoped by acts_as_tenant; a non-matching id is valid and shows a quiet "no match" note.
- **`voter-gate-field` (UX-DR11):** always visible; disabled + lock glyph + exact helper copy while open; editable form once closed (+matched-voter note); read-only when closed but the viewer lacks write. Normal (not error) styling.
- **No Stimulus:** lock/unlock derives from `status` server-side (closing reloads the page). Architecture's `voter-gate` Stimulus controller intentionally deferred — honors the "no speculative JavaScript" guardrail.
- Authorization reuses the ticket `update?` policy (write ∩ subtree); read-only / out-of-subtree → 404.
- **Scope boundary:** the 2-step closure flow + sentiment picker is Story 1.7 (it will match a Voter and write `sentiment_status` during closing). 1.6 only unlocks/validates `voter_id` on an already-closed ticket. Export/widget is 1.8.

### File List

- `app/models/kitchen_cabinet/ticket.rb` (modified — voter_id gate validation + matched_voter)
- `app/controllers/kitchen_cabinet/tickets_controller.rb` (modified — voter action)
- `config/routes.rb` (modified — member patch :voter)
- `app/views/ui/_voter_gate_field.html.erb` (new)
- `app/views/kitchen_cabinet/tickets/show.html.erb` (modified — render gate field)
- `test/models/kitchen_cabinet/ticket_voter_gate_test.rb` (new)
- `test/integration/kitchen_cabinet_voter_gate_test.rb` (new)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-06 | Story 1.6 drafted (BMad create-story) — model-level voter-ID gate (settable only when closed), loose Voter lookup (no FK), always-visible locked/unlocked `voter-gate-field`, `voter` member action. No migration (column exists). Status → ready-for-dev. |
| 2026-10-06 | Story 1.6 implemented (BMad dev-story) — `voter_id_locked_until_closed` validation + `matched_voter` loose lookup, `voter` member action (write∩subtree), `ui/_voter_gate_field` (locked/editable), detail wired. 8 new tests; full suite 131/0, rubocop clean. Status → review. |

## Status

review
