---
story_key: 0-9-hierarchical-user-management
epic: 0
depends_on: 0-8-roles-permissions-catalog
baseline_commit: cd5eab0fc18950ff2cc9caf8fbea3572d12c161b
---

# Story 0.9: Hierarchical user management with scoped visibility

## Story

As an Org Admin,
I want to build a user hierarchy of unlimited depth where each person sees only their own branch,
So that cadre members only access data relevant to them.

## Acceptance Criteria

1. Given roles exist (Story 0.8) and an Org Admin is the tree root, when users are created and the tree is queried, then `closure_tree` maintains the self-referential `users` tree to unlimited depth; whoever creates a user becomes its parent (FR4).
2. Each user's `subtree_ids` are cached (Solid Cache) and invalidated only when the hierarchy changes (FR4, NFR10).
3. Every authorized read is scoped to viewer subtree ∩ organization ∩ module permission; "Get All Details" returns only permitted rows, paginated (FR4, NFR12).
4. Creating a user is allowed only for a role with `can_create_users` (default `org_admin` only), enforced in policy not just UI, and the creator assigns an existing role (FR7).
5. An organization may have more than one `org_admin` (FR3).
6. The per-model isolation test from Story 0.2 passes for `User`.

## Tasks/Subtasks

- [x] Task 1: Self-referential tree (AC: 1)
  - [x] `closure_tree` on `User` via `user_hierarchies`; creator becomes parent; unlimited depth
- [x] Task 2: Cached subtree (AC: 2)
  - [x] `subtree_ids` cached in Solid Cache, invalidated only on hierarchy change
- [x] Task 3: Scoped reads (AC: 3)
  - [x] Reads scoped to viewer subtree ∩ organization ∩ module permission; "Get All Details" paginated, permitted rows only
- [x] Task 4: Creation authorization (AC: 4, 5)
  - [x] `UserPolicy` enforces `can_create_users` (default `org_admin`), not just UI; creator assigns an existing role; multiple `org_admin`s allowed per org
- [x] Task 5: Tests + verify (AC: all, incl. 6)
  - [x] Hierarchy/subtree tests; policy enforcement; per-model isolation test passes for `User`

## Dev Notes

- **Context:** architecture §User hierarchy (`closure_tree`, cached subtree, Pundit scoping). Brief FR3/FR4/FR7, NFR10/NFR12.
- **Scope guard:** ONLY the hierarchy, cached subtree, scoped reads, and creation authorization. The roles catalog itself is Story 0.8; the dashboard/export surfaces that consume these scopes are Story 0.14.
- **Tenancy:** scoping is the intersection of three guards — viewer subtree, organization (tenant), and module permission — so a cadre member sees only their own branch within their org.

## Dev Agent Record

### Debug Log

- `subtree_ids` is cached in Solid Cache and invalidated only on hierarchy change, so the common scoped-read path avoids recursive closure-table queries.
- `can_create_users` is enforced in `UserPolicy` (not only hidden in the UI), and the creator is recorded as the new user's parent.

### Implementation Plan

`create_user_hierarchies` migration → `closure_tree` on `User` + cached `subtree_ids` → `UserPolicy` (scoped reads + `can_create_users` enforcement) → `UsersController` + index/new views → routes → hierarchy/subtree + management integration tests + `User` isolation test.

### Completion Notes

- `closure_tree` maintains an unlimited-depth user tree; the creator becomes the parent; multiple `org_admin`s per org are allowed.
- Reads are scoped to viewer subtree ∩ organization ∩ module permission with paginated "Get All Details"; `subtree_ids` is cached and invalidated only on hierarchy change.
- User creation requires a `can_create_users` role, enforced in policy. The Story 0.2 per-model isolation test passes for `User`.

## File List

- `app/models/user.rb` (modified — `closure_tree`, cached subtree)
- `app/models/organization.rb` (modified — tree root wiring)
- `app/policies/user_policy.rb` (added — scope + `can_create_users`)
- `app/controllers/users_controller.rb` (added)
- `app/views/users/index.html.erb`, `new.html.erb` (added)
- `db/migrate/20261004140500_create_user_hierarchies.rb` (added)
- `db/schema.rb`, `config/routes.rb` (modified)
- `test/models/user_hierarchy_test.rb`, `test/integration/user_management_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.9 **backfilled from commit b243127** — `closure_tree` user hierarchy with cached `subtree_ids`, subtree ∩ org ∩ permission scoping, and policy-enforced `can_create_users`. Status → review. |

## Status

review
