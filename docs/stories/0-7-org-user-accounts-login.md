---
story_key: 0-7-org-user-accounts-login
epic: 0
depends_on: 0-6-org-deactivation-cascade
baseline_commit: 605725313967e109ab56037e6762f02b656a2fcf
---

# Story 0.7: Organization-facing user accounts and login

## Story

As an Org Admin,
I want org users to authenticate at the clean root path,
So that a campaign's people can securely access their organization.

## Acceptance Criteria

1. Given an organization exists, when the User scope is added, then a `users` table exists (`organization_id` required, `parent_id` nullable, `role_id`, name, email, phone, photo, `active`, `last_login_at`, `login_count`) (FR2).
2. `devise_for :users, path: ''` provides login with `database_authenticatable`, `recoverable`, `rememberable`, `trackable`, `lockable (:both)` — **no** `registerable` (FR2, NFR4).
3. On each login the timestamp is recorded and the login counter increments, surfaced in the top bar (NFR26).
4. A user in a deactivated org cannot authenticate (reuses Story 0.6).

## Tasks/Subtasks

- [x] Task 1: Users table + migration (AC: 1)
  - [x] `users`: `organization_id` (required), `parent_id` (nullable), `role_id`, name, email, phone, photo, `active`, `last_login_at`, `login_count`
  - [x] Active Storage tables installed for the user photo
- [x] Task 2: Second Devise scope (AC: 2)
  - [x] `devise_for :users, path: ''` → login at the clean root; modules `database_authenticatable`, `recoverable`, `rememberable`, `trackable`, `lockable (:both)`; **no** `registerable`
  - [x] Reconcile `lockable` strategy with Admin's `:time` (Story 0.3) → `:both` for users
- [x] Task 3: Login tracking (AC: 3)
  - [x] Record `last_login_at` and increment `login_count` on each sign-in; surface in the top bar
- [x] Task 4: Deactivated-org cutoff (AC: 4)
  - [x] Reuse Story 0.6 `active_for_authentication?` so a user in an inactive org cannot authenticate
- [x] Task 5: Tests + verify (AC: all)
  - [x] User login, login-count increment, no-registration, deactivated-org cutoff

## Dev Notes

- **Context:** architecture §Auth & Security (two Devise scopes — Admin at `/console`, User at root). Brief FR2, NFR4, NFR26.
- **Scope guard:** ONLY the User scope + login + login tracking. Roles catalog is Story 0.8; the self-referential hierarchy (`closure_tree`) + scoped visibility + `can_create_users` enforcement is Story 0.9. No org-facing self-registration ever.
- **Tenancy:** `User` is tenant-scoped (`organization_id` required); the second Devise scope lives at the clean root, distinct from the steel-skin Console.

## Dev Agent Record

### Debug Log

- This is the second Devise scope; `lockable` was reconciled to `:both` for users (Admin stayed `:time` from Story 0.3).
- `registerable` is deliberately omitted — org users are provisioned by an Org Admin (Story 0.9), never self-registered.

### Implementation Plan

`devise_create_users` migration (+ Active Storage) → `User` model (Devise modules, login tracking, `active_for_authentication?` reuse) → `devise_for :users, path: ''` → top-bar login timestamp/count → user login + model tests.

### Completion Notes

- `users` carries the full foundation shape (`organization_id` required, `parent_id` nullable, `role_id`, profile fields, `active`, login tracking).
- Login at the clean root via the second Devise scope, with no self-registration; `last_login_at`/`login_count` update each sign-in and show in the top bar.
- Users in a deactivated org can't authenticate, reusing the Story 0.6 cascade.

## File List

- `app/models/user.rb` (modified — Devise modules, login tracking)
- `app/controllers/application_controller.rb` (modified — authenticate_user!)
- `app/views/ui/_top_bar.html.erb` (modified — login timestamp + count)
- `db/migrate/20261004140200_devise_create_users.rb` (added)
- `db/migrate/..._create_active_storage_tables.active_storage.rb` (added)
- `db/schema.rb`, `config/routes.rb` (modified — `devise_for :users, path: ''`)
- `test/integration/user_login_test.rb`, `test/models/user_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.7 **backfilled from commit cd5eab0** — org-facing `User` Devise scope at the clean root (no registerable), full users table, login tracking in the top bar, and deactivated-org cutoff. Status → review. |

## Status

review
