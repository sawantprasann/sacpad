---
story_key: 0-2-tenant-isolation-spine
epic: 0
depends_on: 0-1-scaffold
baseline_commit: df9c8d3caeedd5bf81499e57c7385b7cb0cabe55
---

# Story 0.2: Organization tenant boundary and isolation spine

## Story

As a developer,
I want an `Organization` model with the defense-in-depth tenant-isolation spine and an isolation test harness,
So that no later feature can leak one organization's data to another.

## Acceptance Criteria

1. An `organizations` table exists: `active` boolean (default true), `current_party_id` bigint (nullable), polymorphic `constituency_id`/`constituency_type` (nullable), timestamps. (FR2, FR12)
2. `acts_as_tenant` auto-scopes tenant-scoped models to a thread-local current organization and **raises** on an unscoped query rather than returning rows (`require_tenant = true`). (FR10, NFR1)
3. A Pundit `ApplicationPolicy` base + an `ApplicationController` scoping hook exist, plus an `OrganizationScoped` model concern establishing the convention that every domain table carries a `NOT NULL`, FK-constrained, denormalized `organization_id`. (FR10, NFR1)
4. A reusable cross-tenant isolation test helper exists and is demonstrated: "Org A cannot read/update/delete an Org B record (expect 404, not 403)" plus "an unscoped query raises" — runnable per model. (FR11, NFR3)

## Tasks/Subtasks

- [x] Task 1: Organization model + migration (AC: 1)
  - [x] `organizations` table (name, active default true, current_party_id nullable, polymorphic constituency nullable, timestamps)
  - [x] Organization model (the tenant; no acts_as_tenant on itself; `active` scope, name presence)
- [x] Task 2: acts_as_tenant spine (AC: 2)
  - [x] Initializer: `require_tenant = true` (raise on unscoped tenant queries)
  - [x] `ApplicationController` sets current tenant via `set_current_tenant_through_filter` (nil stub until auth in 0.7)
- [x] Task 3: Authorization + scoping convention (AC: 3)
  - [x] `ApplicationPolicy` base (org Scope defers to acts_as_tenant; subtree/module added in 0.8/0.9)
  - [x] `OrganizationScoped` concern: `acts_as_tenant(:organization)` + `organization_id` presence validation
  - [x] Included Pundit in `ApplicationController`; `Pundit::NotAuthorizedError` → 404 (not 403)
- [x] Task 4: Isolation test harness (AC: 4)
  - [x] Reusable `TenantIsolation` module (A-cannot-read/update/delete-B → 404 / 0 rows; unscoped raises)
  - [x] Demonstrated against a self-contained probe model; proved require_tenant raises + org_id presence
- [x] Task 5: Verify (AC: all)
  - [x] Migrated; full suite green (6 runs, 21 assertions, 0 failures); rubocop clean (34 files, 0 offenses)

## Dev Notes

- **Context:** `docs/architecture.md` (Core Architectural Decisions → tenant isolation four layers; Patterns → "never bare Model.where / always policy-scope inside tenant context"). FR2/FR10/FR11/FR12, NFR1/NFR3.
- **Scope guard:** NO Devise/users/roles (0.3/0.7/0.8), NO domain modules, NO Voter (0.15). Only the Organization boundary + isolation machinery + reusable test helper.
- **Admin exception:** `Admin` (0.3) will operate OUTSIDE acts_as_tenant via `ActsAsTenant.without_tenant` — not built here, noted so the base controller hook stays org-side only.

## Dev Agent Record

### Debug Log

- Initial probe table omitted timestamps → the isolation helper's cross-tenant `update_all(updated_at:)` raised `PG::UndefinedColumn`. Fixed by adding `t.timestamps` to the probe (real domain models always carry timestamps).
- Replaced the generated `organizations.yml` fixtures (they referenced non-existent polymorphic `Constituency` rows and would fail to load).

### Implementation Plan

Organization (tenant) model + migration → acts_as_tenant initializer (`require_tenant = true`) → ApplicationController filter + Pundit + 404-on-unauthorized → ApplicationPolicy base + OrganizationScoped concern → reusable TenantIsolation test module proven against a self-contained probe model.

### Completion Notes

- Built the tenant-isolation spine: layer 1 (controller sets current org — stubbed nil until auth), layer 3 (`acts_as_tenant` raising on unscoped), and the convention for layers 2/4 (`OrganizationScoped` requires denormalized `organization_id`; including models' migrations must add it NOT NULL + FK). Postgres RLS (layer 5, Voter) is Story 0.15/6.
- `ApplicationPolicy` base scopes to org via acts_as_tenant; module-permission + hierarchy-subtree narrowing deferred to Stories 0.8/0.9 (noted inline).
- `Pundit::NotAuthorizedError` rescued → 404 (never 403), per the architecture's "never confirm existence" rule.
- Reusable `TenantIsolation` test module proves A-cannot-read/update/delete-B and that unscoped queries raise — the pattern every future scoped model reuses (release-gating per NFR3). Demonstrated with a self-contained probe model (no dependency on yet-unbuilt domain models).
- Scope guard held: no Devise/users/roles, no domain modules, no Voter. `Admin` will run OUTSIDE acts_as_tenant via `without_tenant` (Story 0.3) — not built here.
- Verified: migrate clean; `bin/rails test` 6 runs / 21 assertions / 0 failures; `bin/rubocop` 0 offenses.

## File List

- `db/migrate/20261004133609_create_organizations.rb` (added)
- `db/schema.rb` (updated by migration)
- `app/models/organization.rb` (modified)
- `config/initializers/acts_as_tenant.rb` (added)
- `app/controllers/application_controller.rb` (modified — Pundit, tenant filter, 404 rescue)
- `app/policies/application_policy.rb` (added)
- `app/models/concerns/organization_scoped.rb` (added)
- `test/support/tenant_isolation.rb` (added — reusable isolation assertions)
- `test/models/tenant_isolation_spine_test.rb` (added)
- `test/fixtures/organizations.yml` (emptied)
- `test/models/organization_test.rb` (generated stub)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.2 implemented — Organization tenant model + acts_as_tenant isolation spine + ApplicationPolicy base + OrganizationScoped concern + reusable isolation test harness. Tests + rubocop green. Status → review. |

## Status

review
