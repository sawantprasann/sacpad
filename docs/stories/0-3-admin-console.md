---
story_key: 0-3-admin-console
epic: 0
depends_on: 0-2-tenant-isolation-spine
baseline_commit: da8962e85617894e07944f2cd73f443b835965ed
---

# Story 0.3: Admin account type and Platform Console entry

## Story

As a platform operator,
I want a separate `Admin` account that logs in at `/console` into a distinct operator shell,
So that platform operations are architecturally separate from any organization's users.

## Acceptance Criteria

1. A standalone `admins` table exists with a `tier` (`full`/`ops`) and an `active` flag, and **no** `organization_id`/`parent_id`/`role_id`.
2. `devise_for :admins, path: 'console'` provides login at `/console/sign_in` with `database_authenticatable`, `trackable`, `lockable` (`unlock_strategy: :time`) — **no** `registerable`, **no** `recoverable`.
3. Authenticated admins reach a Platform Console shell using a constant neutral **steel skin** (never party-themed); the console login is not linked from any org-facing page.
4. `Admin` is NOT a tenant-scoped model and never runs through `acts_as_tenant`; it has no `organization_id`. A `User`-scoped query can never return an `admins` row (separate table).
5. The console dashboard requires authentication (unauthenticated → redirected to `/console/sign_in`).

## Tasks/Subtasks

- [x] Task 1: Devise base install (AC: 2)
  - [x] `rails g devise:install`; set `lock_strategy = :failed_attempts`, `unlock_strategy = :time`, `maximum_attempts = 20`, `unlock_in = 1.hour` (note in devise.rb: User's `:both` reconciled in 0.7)
- [x] Task 2: Admin model + migration (AC: 1, 2, 4)
  - [x] `admins` table: name, email, encrypted_password, trackable + lockable fields, `tier` enum, `active` default true — **no** org/parent/role columns; **no** recoverable/rememberable columns
  - [x] `Admin` model: `devise :database_authenticatable, :trackable, :lockable, :validatable`; `tier` enum (full/ops); `active_for_authentication?` checks `active`
- [x] Task 3: Routes + Console namespace (AC: 2, 3, 5)
  - [x] `devise_for :admins, path: "console"`; `namespace :console { root "dashboard#index" }`
  - [x] `Console::BaseController` < `ActionController::Base` (authenticate_admin!, steel layout, NOT org-side ApplicationController so no acts_as_tenant); `Console::DashboardController#index`
- [x] Task 4: Steel-skin console layout (AC: 3)
  - [x] `layouts/console.html.erb` — neutral steel chrome (`#1D2939`), never the party accent
- [x] Task 5: Tests + verify (AC: all)
  - [x] Admin has no org/parent/role + not tenant-scoped; tier enum; unauthenticated console → redirect to `/console/sign_in`; active check; no reset_password column
  - [x] Migrate; suite green (13 runs, 38 assertions); rubocop clean (41 files, 0 offenses)

## Dev Notes

- **Context:** architecture §Auth & Security (two Devise scopes; Admin outside tenancy; steel skin) and §Project Structure (Console:: namespace). Brief §2/§3.0.
- **Scope guard:** ONLY the Admin scope + console entry. NO users scope (0.7), NO roles (0.8), NO org lifecycle (0.5), NO cross-org data viewing/logging (0.11). Console dashboard is a shell placeholder.
- **Tenancy:** Admin never includes `OrganizationScoped`. Console controllers touch no tenant-scoped models in this story; cross-org data access via `ActsAsTenant.without_tenant` + logging arrives in 0.11.

## Dev Agent Record

### Debug Log

- `rails g devise Admin` added a default `devise_for :admins` route and a model with registerable/recoverable/rememberable — rewrote both (path `console`, trimmed modules) and customized the migration (added name/tier/active + trackable/lockable fields; dropped recoverable/rememberable columns).
- Devise `unlock_strategy` is a global config; set to `:time` (correct for Admin, which has no email unlock). User's `:both` (Story 0.7) will be reconciled then — noted in `devise.rb`.
- `Console::BaseController` intentionally inherits `ActionController::Base` (not `ApplicationController`) so it never runs the org-side `acts_as_tenant` filter.

### Implementation Plan

devise:install → Admin model + migration (separate table, no org/parent/role, trackable+lockable) → routes (admins scope at /console + console namespace root) → Console::BaseController (authenticate_admin!, steel layout) + DashboardController → console steel layout → model + console-access tests.

### Completion Notes

- `Admin` is a genuinely separate account type: own table, `tier` enum (full/ops), `active` flag, **no** `organization_id`/`parent_id`/`role_id`, and it does **not** include `OrganizationScoped` — so it never runs through `acts_as_tenant` and a `User`-scoped query can never return it (proven in `AdminTest`).
- Auth: `devise_for :admins, path: "console"` → `/console/sign_in`; modules `database_authenticatable`/`trackable`/`lockable(:time)` + `validatable`; **no** registerable/recoverable/rememberable (out-of-band recovery). Login hardening (rack-attack) is a later security story.
- Console wears the constant neutral **steel skin** (`#1D2939`), never party-themed; the login path is deliberately non-obvious and unlinked from org-facing UI.
- `Console::BaseController` requires `authenticate_admin!` and rescues `Pundit::NotAuthorizedError` → 404. Cross-org data viewing (`without_tenant` + audit logging) is Story 0.11; this story's dashboard is a shell placeholder touching no tenant-scoped models.
- Verified: migrate clean; `bin/rails test` → 13 runs / 38 assertions / 0 failures; `bin/rubocop` → 0 offenses.

## File List

- `config/initializers/devise.rb` (added by devise:install; set lock/unlock strategy)
- `db/migrate/20261004134506_devise_create_admins.rb` (added/customized)
- `db/schema.rb` (updated)
- `app/models/admin.rb` (modified — separate account type, tier enum, active check)
- `config/routes.rb` (modified — admins scope at /console + console namespace root)
- `app/controllers/console/base_controller.rb` (added)
- `app/controllers/console/dashboard_controller.rb` (added)
- `app/views/layouts/console.html.erb` (added — steel skin)
- `app/views/console/dashboard/index.html.erb` (added)
- `test/models/admin_test.rb` (modified)
- `test/integration/console_access_test.rb` (added)
- `test/fixtures/admins.yml` (emptied)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.3 implemented — `Admin` account type (separate table, tier, no org/parent/role) + Devise `:admins` scope at `/console` + steel-skin Platform Console shell behind `authenticate_admin!`. Tests + rubocop green. Status → review. |

## Status

review
