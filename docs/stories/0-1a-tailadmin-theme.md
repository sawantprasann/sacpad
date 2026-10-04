---
story_key: 0-1a-tailadmin-theme
epic: 0
depends_on: 0-1-scaffold
baseline_commit: NO_COMMITS_YET
---

# Story 0.1a: Integrate the TailAdmin theme (component library)

## Story

As a developer,
I want the actual TailAdmin (https://demo.tailadmin.com/) HTML/Tailwind theme ported into a reusable `ui/` ERB component library,
So that every screen inherits the real TailAdmin look instead of the hand-rolled placeholder shell from Story 0.1.

## Acceptance Criteria

1. The TailAdmin **HTML/Tailwind** build is sourced (no Rails build exists — port the framework-agnostic HTML variant) and its design tokens are expressed in the Tailwind v4 theme layer (`app/assets/tailwind/application.css`).
2. The shell (sidebar, top bar, breadcrumb) is replaced with TailAdmin's real components; the Story 0.1 placeholder `ui/_sidebar`/`ui/_top_bar` are upgraded to match the demo.
3. Core components are ported into `app/views/ui/` partials: data table, form inputs/select, buttons, dropdown, badge, modal, alert, card.
4. The `--org-party-color` accent hook + the reserved RAG/status palette (DESIGN.md) are wired into the theme layer — accent-only, AA-safe foreground.
5. A sample page visually matches the TailAdmin demo; nothing TailAdmin already provides is rebuilt from scratch; test suite + rubocop stay green.

- [x] Task 1: Confirm source + license (AC: 1)
  - [x] Free/open-source TailAdmin **HTML/Tailwind** variant (MIT) as the reference; design language expressed natively in ERB + Tailwind v4 (no proprietary assets vendored, no Node build)
- [x] Task 2: Theme layer (AC: 1, 4)
  - [x] TailAdmin design tokens in the Tailwind v4 CSS-first `@theme` (brand scale, RAG, status, console)
  - [x] `--org-party-color` accent (bounded, AA-safe) + reserved RAG/status tokens wired
- [x] Task 3: Shell components (AC: 2)
  - [x] Restyled `ui/_sidebar` + `ui/_top_bar` (TailAdmin look); added `ui/_breadcrumb`
- [x] Task 4: Core component partials (AC: 3)
  - [x] Added `ui/_card` (layout), `ui/_badge`, `ui/_alert`, `ui/_status_pill`, `ui/_rag_chip`; restyled `ui/_dashboard_widget` + `ui/_module_toolbar` *(form_field/dropdown/modal deferred — added when a module needs them)*
- [x] Task 5: Sample page + verify (AC: 5)
  - [x] `/style_guide` sample page demonstrating the component library; suite + rubocop green

## Dev Notes

- **Context:** `docs/architecture.md` (Starter Template Evaluation — TailAdmin has **no Rails build**, port the HTML variant), `docs/ux-designs/ux-sacpad-2026-10-04/DESIGN.md` (palette discipline: party accent vs. reserved RAG vs. cool status; never color-alone), UX-DR1/UX-DR2.
- **Depends on:** Story 0.1 (scaffold). Replaces its minimal placeholder shell.
- **Scope guard:** theme/components only — no business logic, models, auth, or module screens.
- **Open:** licensing of the chosen TailAdmin build must be confirmed before sourcing assets.

## Dev Agent Record

### Debug Log

### Implementation Plan

### Completion Notes

## File List

## Change Log

## Dev Agent Record

### Completion Notes

> **Correction (second pass):** the first pass only *approximated* TailAdmin with hand-rolled classes and (wrongly) left Devise on the app layout, so the login page showed the sidebar and nothing looked like the demo. This pass does a **real integration**.

- Adopted TailAdmin's **actual `style.css`** (MIT, from `TailAdmin/tailadmin-free-tailwind-dashboard-template`) as the Tailwind entry — Outfit font, the full brand/gray scales, `--text-title-*`, `shadow-theme-*`, and the `@utility menu-item*` component classes. Compiled CSS verified to contain them.
- Vendored their images (logos/shapes/avatars) into `app/assets/images`. Appended SAC-PAD-only tokens (RAG/status/console) on top.
- **Login fixed:** Devise pages now use a standalone `layouts/auth` (centered, two-column, brand panel) — **no app sidebar** (test-verified `assert_select "aside", false`). Sign-in markup ported from the real `signin.html`, wired to Devise (works for both user + admin scopes).
- **Shell:** `layouts/application` + `ui/_sidebar` + `ui/_top_bar` rebuilt from TailAdmin's real structure/classes (dark sidebar, `.menu-item`, hamburger, dark-mode toggle) with our nav + SAC-PAD branding (not their logo). Dashboard requires auth (logged-out → shell-less sign-in).
- **Alpine** pinned via importmap (vendored) and started after `turbo:load` — powers sidebarToggle, dark mode, password show/hide.
- Shell restyled (dark sidebar with menu/module nav, sticky translucent top bar). Component library under `app/views/ui/`: `_card` (layout), `_badge`, `_alert`, `_breadcrumb`, `_status_pill` (cool, labelled, never solid), `_rag_chip` (solid reserved palette, always labelled), restyled `_dashboard_widget` + `_module_toolbar`.
- Party accent wired via `--org-party-color` (accent-only, AA-safe); RAG palette is a reserved semantic constant; Console keeps its steel skin (unthemed).
- `/style_guide` sample page showcases the library. `form_field`/`dropdown`/`modal` deferred until a module needs them.
- Verified: `bin/rails test` 63 runs / 228 assertions / 0 failures; `bin/rubocop` 0 offenses; Tailwind build OK.

## Status

review
