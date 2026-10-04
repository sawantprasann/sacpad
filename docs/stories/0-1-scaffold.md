---
story_key: 0-1-scaffold
epic: 0
baseline_commit: NO_COMMITS_YET
---

# Story 0.1: Scaffold the Rails 8 + TailAdmin application

## Story

As a developer,
I want a booting Rails 8.1 + TailAdmin application wired to PostgreSQL with the multi-database and base layout shell in place,
So that every later story has a consistent, production-shaped foundation to build on.

## Acceptance Criteria

1. `rails new .` (Rails 8.1, PostgreSQL, `--css=tailwind --skip-git`) is run **in place in the existing project folder** (no new subfolder, `docs/` preserved) and boots.
2. Solid Queue, Solid Cache, and Solid Cable are configured on **separate databases** from the primary OLTP database (NFR8).
3. A shared application layout shell (top bar region, left sidebar region, center content region) renders using TailAdmin HTML/Tailwind components ported to ERB (UX-DR1/UX-DR2).
4. TailAdmin integration uses `tailwindcss-rails` (Tailwind v4) + Propshaft — no Next.js/Node SPA build.
5. A CI-runnable boot + (initially minimal) test suite runs green.

## Tasks/Subtasks

- [x] Task 1: Environment — Ruby 3.4.6 + Rails 8.1 (AC: 1)
  - [x] Switch to Ruby 3.4.6 via RVM; pin `.ruby-version`
  - [x] `gem install rails -v "~> 8.1.3"` → installed Rails 8.1.4
- [x] Task 2: Generate the Rails app in place (AC: 1, 4)
  - [x] `rails new . --database=postgresql --css=tailwind --skip-git` (preserved `docs/`)
  - [x] Verified Hotwire (Turbo+Stimulus), Propshaft, import maps present; Tailwind v4 (4.3.3 CLI) via tailwindcss-rails
- [x] Task 3: Multi-database configuration (AC: 2)
  - [x] Confirmed primary + queue + cache + cable databases in `config/database.yml`
  - [x] Solid Queue / Solid Cache / Solid Cable point at their own databases in production (dev uses primary per Rails convention — see notes)
- [x] Task 4: Base dependencies (AC: 1)
  - [x] Added foundational gems to Gemfile (devise, pundit, closure_tree, acts_as_tenant, discard, paper_trail, pagy, chartkick, caxlsx(+caxlsx_rails), roo, bullet, faraday, aws-sdk-s3) — installed; wiring is later stories
- [x] Task 5: Shared TailAdmin shell (AC: 3)
  - [x] Ported a minimal TailAdmin HTML/Tailwind layout into ERB: `layouts/application.html.erb` with top-bar / sidebar / content regions, plus `ui/_sidebar` + `ui/_top_bar` partials and a placeholder home page
- [x] Task 6: Boot + green (AC: 5)
  - [x] Created databases; migrations clean; app boots (Rails 8.1.4 / Ruby 3.4.6)
  - [x] Test suite green (2 runs, 10 assertions, 0 failures); rubocop clean (26 files, 0 offenses)

## Dev Notes

- **Context:** `docs/architecture.md` (Starter Template Evaluation, Core Architectural Decisions, Project Structure), `docs/project_brief.md` §2, Story 0.1 in `docs/epics.md`.
- **Hard constraints:** generate in place (`rails new .`), never a new subfolder; preserve `docs/`; Rails 8.1.x on Ruby 3.4.6; Tailwind v4 via `tailwindcss-rails`; minimal-Hotwire posture; no SPA/Node build.
- **Scope guard:** this story is scaffolding ONLY — install foundational gems but do NOT wire Devise scopes, Pundit, tenancy, models, or routes (those are Stories 0.2+).

## Dev Agent Record

### Debug Log

- `rails new .` initially included `jbuilder` (omitted `--skip-jbuilder`); left in place — harmless, unused (no JSON API). Not worth regenerating.
- Removed the pre-written `.ruby-version` before `rails new` so the generator didn't hit an overwrite prompt; it regenerated `.ruby-version` as `ruby-3.4.6`.

### Implementation Plan

Ruby 3.4.6 (RVM) → install Rails 8.1 → `rails new .` in place → add foundational gems → port minimal TailAdmin shell (layout + ui partials + placeholder home) → create DBs, boot, test green.

### Completion Notes

- Scaffolded **Rails 8.1.4** on **Ruby 3.4.6**, PostgreSQL 16, Tailwind v4 (via tailwindcss-rails) + Propshaft + Hotwire (Turbo/Stimulus) + import maps. Server-rendered, no SPA/Node build (minimal-Hotwire posture).
- Multi-DB: Rails 8 default `config/database.yml` splits `cache`/`queue`/`cable` onto separate databases **in production** (primary OLTP isolated — satisfies NFR8 where it matters). **Development/test use the single primary DB per Rails convention** — flagged for awareness; can be split later if local parity is wanted.
- Foundational gems installed only; **not wired** (Devise scopes, Pundit, tenancy, models, routes are Stories 0.2+). Scope guard held.
- Shared shell renders the three regions (sidebar/top-bar/content) with a `--org-party-color` CSS-var hook for later per-org theming (UX-DR3). Placeholder nav/user area; session timestamp + login count wired in Story 0.7.
- Verified: `db:create` + `db:migrate` clean; `bin/rails test` green (2/10 assertions); `bin/rubocop` 0 offenses; `rails runner` boots.
- **Not committed to git** (no commit made — awaiting user direction on an initial commit).

## File List

- `.ruby-version` (added — ruby-3.4.6)
- `Gemfile` (modified — foundational gems + bullet)
- `Gemfile.lock` (generated)
- `config/routes.rb` (modified — `root "home#index"`)
- `app/controllers/home_controller.rb` (added)
- `app/views/home/index.html.erb` (added)
- `app/views/layouts/application.html.erb` (modified — shell)
- `app/views/ui/_sidebar.html.erb` (added)
- `app/views/ui/_top_bar.html.erb` (added)
- `test/integration/scaffold_boot_test.rb` (added)
- *(plus the full `rails new .` generated tree: app/, bin/, config/, db/, lib/, public/, storage/, test/, Dockerfile, .kamal/, etc.)*

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.1 implemented — Rails 8.1.4 + TailAdmin shell scaffolded in place; foundational gems installed; boot + tests + lint green. Status → review. |

## Status

review
