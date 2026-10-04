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

## Tasks/Subtasks

- [ ] Task 1: Confirm source + license (AC: 1)
  - [ ] Decide TailAdmin build: free/open-source HTML variant vs. Pro; confirm license allows use
  - [ ] Obtain the HTML/Tailwind assets (components, tokens)
- [ ] Task 2: Theme layer (AC: 1, 4)
  - [ ] Express TailAdmin tokens (colors, spacing, radii, typography) in the Tailwind v4 CSS-first theme
  - [ ] Wire `--org-party-color` accent (bounded) + reserved RAG/status tokens (DESIGN.md)
- [ ] Task 3: Shell components (AC: 2)
  - [ ] Replace `ui/_sidebar`, `ui/_top_bar`; add `ui/_breadcrumb`
- [ ] Task 4: Core component partials (AC: 3)
  - [ ] Port `ui/_data_table`, `ui/_form_field`, `ui/_button`, `ui/_dropdown`, `ui/_badge`, `ui/_modal`, `ui/_alert`, `ui/_card`
- [ ] Task 5: Sample page + verify (AC: 5)
  - [ ] Update the placeholder home to demonstrate the ported components
  - [ ] Keep tests + rubocop green; add a render test for the component partials

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

## Status

ready-for-dev
