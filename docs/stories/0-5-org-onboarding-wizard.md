---
story_key: 0-5-org-onboarding-wizard
epic: 0
depends_on: 0-4-reference-data-catalog-editor
baseline_commit: b2431273d76591c284aa4b9a20e7777162ddafdb
---

# Story 0.5: Organization onboarding wizard with constituency link

## Story

As a platform operator,
I want a create-organization wizard that sets the org's constituency, initial party, and first Org Admin,
So that a new politician's operation can be stood up end to end.

## Acceptance Criteria

1. Given geography and parties exist (Story 0.4), when an Admin runs the create-organization wizard, then the wizard is linear and resumable and sets the org identity, a one-time **constituency** choice (exactly one Loksabha **or** one Assembly), and an initial party affiliation (FR12, FR13, UX-DR17).
2. The wizard cannot finish without provisioning at least one Org Admin account (FR13, UX-DR17).
3. An Organizations health list shows active/inactive, user counts, and last activity, filtered to assigned orgs only for an `ops`-tier Admin (FR13, UX-DR19/UX-DR20).
4. `organization.villages`/`assemblies` derive correctly from the constituency type.

## Tasks/Subtasks

- [x] Task 1: Onboarding wizard controller (AC: 1, 2)
  - [x] `Console::OrganizationsController` new/create flow — org identity + one-time constituency (one Loksabha OR one Assembly) + initial party affiliation
  - [x] Create org + first Org Admin in a single transaction; refuse to finish without an Org Admin
- [x] Task 2: Constituency link + derivation (AC: 1, 4)
  - [x] `party_memberships` join + constituency columns on `organization`; `villages`/`assemblies` derive from the chosen constituency type
- [x] Task 3: Admin ↔ org assignment (AC: 3)
  - [x] `admin_organizations` join so an `ops`-tier Admin is scoped to assigned orgs
- [x] Task 4: Organizations health list (AC: 3)
  - [x] Index showing active/inactive, user counts, last activity; filtered to assigned orgs for `ops` tier
- [x] Task 5: Tests + verify (AC: all)
  - [x] Wizard provisions org + Org Admin in one transaction; cannot finish without Org Admin; constituency derivation; ops-tier filtering

## Dev Notes

- **Context:** architecture §Org lifecycle + §Console. Brief FR12/FR13, UX-DR17/UX-DR19/UX-DR20.
- **Scope guard:** ONLY org creation (identity + constituency + initial party + mandatory first Org Admin) and the health list. Deactivation cascade is Story 0.6 (same commit, separate story). The User scope/login itself is Story 0.7.
- **Tenancy:** `AdminOrganization` scopes `ops`-tier operators to assigned orgs only; unassigned orgs are absent from the list, not shown-and-locked.

## Dev Agent Record

### Debug Log

- Org + initial Org Admin are created in one DB transaction so a half-provisioned org (no admin) can never exist.
- Constituency is a one-time choice of exactly one Loksabha **or** one Assembly; `villages`/`assemblies` are derived from that choice rather than entered.

### Implementation Plan

`admin_organizations` + `party_memberships` migration → Organization constituency/derivation + associations → `Console::OrganizationsController` wizard (new/create in a transaction with mandatory Org Admin) → Organizations health index (filtered for ops tier) → console routes → wizard + filtering integration tests.

### Completion Notes

- The create-organization wizard sets identity, a one-time constituency, and an initial party, and refuses to complete without at least one Org Admin — all in a single transaction.
- The Organizations health list surfaces active/inactive, user counts, and last activity, and is filtered to assigned orgs for `ops`-tier Admins.
- `organization.villages`/`assemblies` derive from the constituency type.

## File List

- `app/controllers/console/organizations_controller.rb` (added — wizard + health list)
- `app/models/organization.rb` (modified — constituency link + derivation)
- `app/models/admin.rb` (modified — assigned-orgs association)
- `app/models/admin_organization.rb`, `app/models/party_membership.rb` (added)
- `app/views/console/organizations/index.html.erb`, `new.html.erb`, `show.html.erb` (added)
- `db/migrate/..._create_party_memberships_and_admin_organizations.rb` (added)
- `db/schema.rb`, `config/routes.rb` (modified)
- `test/integration/console_organizations_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.5 **backfilled from commit 67696cd** (shared with 0.6) — create-organization wizard (identity + one-time constituency + initial party + mandatory first Org Admin, single transaction) and the Organizations health list with `ops`-tier filtering. Status → review. |

## Status

review
