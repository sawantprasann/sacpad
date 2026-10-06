---
story_key: 0-14-shared-chrome-export-dashboard
epic: 0
depends_on: 0-13-operational-health-view
baseline_commit: d8a1aaab27a764d3bd5374e006accfa667ae5708
---

# Story 0.14: Shared chrome, export, and the Organization Dashboard framework

## Story

As an org user,
I want a consistent themed shell with a shared toolbar and a permission-aware dashboard,
So that every module feels like one tool and shows only what I'm allowed to see.

## Acceptance Criteria

1. Given an authenticated org user, when any org-side surface renders, then the shared chrome renders — top bar (app name, user photo/name, session timestamp, login count, settings), module toolbar (Export Excel · Prepare Chart · Bar/Pie/Line · Export Chart · Get All Details), left category sidebar, center table/panel (FR48, UX-DR2).
2. A party-theming engine resolves the org's `Party.color`+logo and applies them as **accent only** (AA-safe foreground auto-computed; Independent orgs use the fallback) — never full-surface, never on the Console (FR-theming, UX-DR3).
3. A reusable Excel + chart export mechanism exists, scoped to the viewer's subtree/org (FR49).
4. The Organization Dashboard is a widget-composition framework: each widget runs through the same scoping and renders only if the viewer's role permits that module; org-admin-only widgets (pending items, hierarchy/user-count, recent-deletions) are gated by capability (FR50, FR51).
5. Reserved RAG colors and workflow-status pills follow the DESIGN.md palette discipline, never by color alone (UX-DR4/UX-DR5/UX-DR7).

## Tasks/Subtasks

- [x] Task 1: Shared chrome (AC: 1)
  - [x] Top bar (app name, user photo/name, session timestamp, login count, settings), `_module_toolbar` (Export Excel · Prepare Chart · Bar/Pie/Line · Export Chart · Get All Details), left category sidebar, center panel
- [x] Task 2: Party-theming engine (AC: 2, 5)
  - [x] Resolve `Party.color`+logo as **accent only**, AA-safe foreground auto-computed, Independent fallback; never full-surface, never on Console; RAG + status pills follow DESIGN.md (never color alone) — `ApplicationHelper`
- [x] Task 3: Reusable export (AC: 3)
  - [x] Excel + chart export mechanism scoped to the viewer's subtree/org
- [x] Task 4: Dashboard widget framework (AC: 4)
  - [x] `_dashboard_widget` composition; each widget re-runs scoping and renders only if role permits the module; org-admin-only widgets (pending items, hierarchy/user-count, recent-deletions) gated by capability
- [x] Task 5: Tests + verify (AC: all)
  - [x] Chrome renders; theming accent + AA + fallback; permission-gated widgets; scoped export

## Dev Notes

- **Context:** architecture §Shared chrome + §Theming + §Dashboard framework. Brief FR48/FR49/FR50/FR51/FR-theming, UX-DR2/UX-DR3/UX-DR4/UX-DR5/UX-DR7.
- **Scope guard:** ONLY the shared shell, theming engine, reusable export, and the dashboard *framework* (widget composition + gating). Concrete module widgets/exports are built in their own epics; this story provides the reusable scaffolding.
- **Tenancy:** every widget and export re-applies the Story 0.9 subtree ∩ org ∩ permission scoping — the framework never trusts the caller to pre-scope.

## Dev Agent Record

### Debug Log

- Theming is applied as **accent only** with an auto-computed AA-safe foreground (never full-surface, never on the Console steel skin); Independent orgs fall back to the neutral palette.
- The dashboard is a widget-composition framework — each widget re-runs scoping and self-gates on module permission + capability, so org-admin-only widgets never leak to other roles.

### Implementation Plan

`ApplicationHelper` theming + AA-foreground + RAG/status-pill helpers → shared `_module_toolbar` + top-bar chrome in `layouts/application` → `_dashboard_widget` composition with permission/capability gating → reusable scoped Excel/chart export → `home#index` dashboard wiring → dashboard integration tests.

### Completion Notes

- The themed shell (top bar, module toolbar, category sidebar, center panel) renders on every org-side surface, with party color/logo applied as accent only (AA-safe foreground, Independent fallback) and never on the Console.
- A reusable Excel + chart export (scoped to subtree/org) and a permission-aware dashboard widget framework (capability-gated org-admin widgets) are established; RAG + status pills follow DESIGN.md discipline.

## File List

- `app/helpers/application_helper.rb` (added/modified — theming, AA foreground, RAG/status pills)
- `app/views/layouts/application.html.erb` (modified — shared chrome)
- `app/views/ui/_module_toolbar.html.erb`, `app/views/ui/_dashboard_widget.html.erb` (added)
- `app/controllers/home_controller.rb`, `app/views/home/index.html.erb` (modified — dashboard)
- `test/integration/dashboard_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.14 **backfilled from commit 183effd** — shared themed chrome + module toolbar, accent-only party-theming engine (AA-safe, Independent fallback), reusable scoped export, and a permission-aware dashboard widget framework. Status → review. |

## Status

review
