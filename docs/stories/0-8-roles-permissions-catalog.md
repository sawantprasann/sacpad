---
story_key: 0-8-roles-permissions-catalog
epic: 0
depends_on: 0-7-org-user-accounts-login
baseline_commit: 64a3eca1e5d11bea1b0e9852ab9731a401ab8fdc
---

# Story 0.8: Roles and permissions catalog with Console editor

## Story

As a platform operator,
I want to define roles as data with per-module access levels,
So that organizations can be given module-scoped roles without a deploy.

## Acceptance Criteria

1. Given an authenticated Admin, when roles are defined in the Console role editor, then `roles` (name, slug, `is_system`, `can_create_users`) and `role_permissions` (role, module enum, `access_level` none/read/write) tables exist (FR5).
2. The editor presents a module × access-level matrix plus a `can_create_users` toggle, and system roles are flagged and protected (FR6, FR14, UX-DR18).
3. `write` implies read; a role with `none` on a module cannot reach that module's data or UI (FR5).
4. Role definition is reachable **only** from the Console; no org-facing create-role UI exists (FR6).
5. The seeded roles include `org_admin` (full access, `can_create_users: true`) and `dreamline_user` (write on every module, `can_create_users: false`) (FR8).

## Tasks/Subtasks

- [x] Task 1: Roles + permissions tables (AC: 1)
  - [x] `roles` (name, slug, `is_system`, `can_create_users`); `role_permissions` (role, module enum, `access_level` none/read/write)
- [x] Task 2: Console role editor (AC: 2, 4)
  - [x] `Console::RolesController` CRUD; module × access-level matrix + `can_create_users` toggle; system roles flagged/protected; Console-only (no org-facing create-role UI)
- [x] Task 3: Access semantics (AC: 3)
  - [x] `write` implies read; `none` blocks a module's data and UI — helper methods on `Role`
- [x] Task 4: Seeds (AC: 5)
  - [x] Seed `org_admin` (full access, `can_create_users: true`) and `dreamline_user` (write everywhere, `can_create_users: false`)
- [x] Task 5: Tests + verify (AC: all)
  - [x] Role model access semantics; console role editor CRUD + system-role protection

## Dev Notes

- **Context:** architecture §Roles & permissions (roles-as-data). Brief FR5/FR6/FR8/FR14, UX-DR18.
- **Scope guard:** ONLY the roles/permissions catalog + Console editor + seeds. Assigning roles to users and enforcing `can_create_users` in policy is Story 0.9. The permission-aware chrome/dashboard gating is Story 0.14.
- **Tenancy:** roles are a global catalog defined by Admin in the Console; there is deliberately no org-facing create-role surface.

## Dev Agent Record

### Debug Log

- `access_level` is an ordered enum so `write` cleanly implies `read`; module access is checked through `Role` helpers rather than scattered comparisons.
- System roles carry `is_system` and are protected from edit/delete in the editor.

### Implementation Plan

`create_roles_and_permissions` migration → `Role` + `RolePermission` models (module enum, access-level helpers, `write`⇒`read`) → `Console::RolesController` + matrix editor views → seed `org_admin` + `dreamline_user` → role model + console role-editor tests.

### Completion Notes

- Roles and per-module permissions are data, editable from a Console-only module × access-level matrix with a `can_create_users` toggle; system roles are flagged and protected.
- `write` implies read; `none` blocks the module entirely. Seeds provide `org_admin` (full, can create users) and `dreamline_user` (write everywhere, cannot create users).

## File List

- `app/models/role.rb`, `app/models/role_permission.rb` (added)
- `app/controllers/console/roles_controller.rb` (added)
- `app/views/console/roles/index.html.erb`, `new.html.erb`, `edit.html.erb`, `_form.html.erb` (added)
- `db/migrate/20261004140100_create_roles_and_permissions.rb` (added)
- `db/seeds.rb` (modified — `org_admin`, `dreamline_user`)
- `db/schema.rb`, `config/routes.rb` (modified)
- `test/models/role_test.rb`, `test/integration/console_roles_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.8 **backfilled from commit 6057253** — roles-as-data catalog (`roles` + `role_permissions`), Console-only module × access-level matrix editor with `can_create_users`, `write`⇒`read` semantics, and `org_admin`/`dreamline_user` seeds. Status → review. |

## Status

review
