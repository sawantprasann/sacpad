---
story_key: 0-11-cross-org-access-banner
epic: 0
depends_on: 0-10-soft-delete-audit-framework
baseline_commit: 564d98ebd1d380875552aa9e1897a1657bbfff11
---

# Story 0.11: Logged Admin cross-org access with persistent banner

## Story

As a platform operator,
I want every time I view an organization's data to be logged and visibly flagged,
So that cross-tenant access by operators is never silent.

## Acceptance Criteria

1. Given an authenticated Admin viewing a specific organization's data, when the org-detail view is opened, then a persistent, non-dismissible `console-org-banner` shows "You're viewing {Org}'s data. This access is logged." for the whole visit (FR17, UX-DR16).
2. An `ActivityLog` entry (who, which org, action, when) is written for the access (FR17, NFR2).
3. The cross-org audit log view in the Console is queryable by actor, organization, and action (FR17).
4. An `ops`-tier Admin can only open orgs it is assigned to; others are absent from the list, not shown-and-locked (UX-DR19).

## Tasks/Subtasks

- [x] Task 1: Cross-org access logging (AC: 2)
  - [x] Writing an `ActivityLog` entry (actor, org, action, when) when an Admin opens an org-detail view, via the Story 0.10 audit framework
- [x] Task 2: Persistent banner (AC: 1)
  - [x] Non-dismissible `_console_org_banner` shown for the whole org visit: "You're viewing {Org}'s data. This access is logged."
- [x] Task 3: Audit log view (AC: 3)
  - [x] `Console::AuditLogsController` + index queryable by actor, organization, and action
- [x] Task 4: Ops-tier scoping (AC: 4)
  - [x] `ops`-tier Admin can only open assigned orgs; unassigned orgs absent from the list
- [x] Task 5: Tests + verify (AC: all)
  - [x] Access writes ActivityLog; banner present; audit view filters; ops-tier restriction

## Dev Notes

- **Context:** architecture §Cross-org access (logged + flagged) + §Audit. Brief FR17, NFR2, UX-DR16/UX-DR19.
- **Scope guard:** ONLY the logged + flagged cross-org *access* and the audit-log view. The audit *framework* (ActivityLog, concerns) is Story 0.10; this story consumes it. `ActsAsTenant.without_tenant` cross-org reads are exercised here (deferred from Story 0.3).
- **Tenancy:** cross-org viewing runs through `without_tenant` but is always logged + banner-flagged; `ops`-tier operators are hard-scoped to assigned orgs (absent, not shown-and-locked).

## Dev Agent Record

### Debug Log

- The banner is intentionally non-dismissible and spans the whole org visit so operator cross-tenant access is never silent.
- Access logging reuses the Story 0.10 `ActivityLog`/`Auditable` plumbing rather than a bespoke logger.

### Implementation Plan

Log an `ActivityLog` entry on org-detail open (reusing 0.10) → add non-dismissible `_console_org_banner` to the org show view → `Console::AuditLogsController` + index filterable by actor/org/action → ops-tier assigned-org restriction → cross-org audit integration tests.

### Completion Notes

- Opening an org's data writes an `ActivityLog` entry and shows a persistent, non-dismissible banner for the whole visit.
- The Console audit-log view is queryable by actor, organization, and action; `ops`-tier Admins can only open assigned orgs (others are absent from the list).

## File List

- `app/controllers/console/audit_logs_controller.rb` (added)
- `app/controllers/console/organizations_controller.rb` (modified — log access)
- `app/views/console/audit_logs/index.html.erb` (added)
- `app/views/console/organizations/show.html.erb` (modified — banner)
- `app/views/ui/_console_org_banner.html.erb` (added)
- `config/routes.rb` (modified)
- `test/integration/console_audit_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.11 **backfilled from commit e2aaeae** — logged + banner-flagged Admin cross-org access, a filterable Console audit-log view, and `ops`-tier assigned-org scoping. Status → review. |

## Status

review
