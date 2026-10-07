---
story_key: 4-1-pr-catalogs
epic: 4
depends_on: 0-4-reference-data-catalog-editor
baseline_commit: da2f13f
---

# Story 4.1: PR catalogs — Global reference data

Status: ready-for-dev

## Story

As a platform operator,
I want PR reference catalogs managed from the Console,
So that PR records use consistent, extensible categorization.

## Acceptance Criteria

1. Given the Console catalog-editor pattern (Story 0.4), when PR catalogs are seeded/managed, then `pr_categories` (6 seeded), `media_platforms`, and `outdoor_ad_types` tables exist and are Admin-editable, global across orgs (FR15).
2. When categories drive the PR left-sidebar filter, then the navigation reflects the six PR category options.

## Tasks / Subtasks

- [ ] Task 1: Create PR reference data models
  - [ ] PR Categories model (seeded with 6 categories: Electronic, Print, Local-Print, Local-Electronic, Outdoor Media, Podcasts/Interviews)
  - [ ] Media Platforms model (platforms like "TV", "Newspaper", "Radio", "Website")
  - [ ] Outdoor Ad Types model (ad types like "Billboard", "Bus Shelter", "Wall Paint")
  - [ ] Migrations for all three tables
  - [ ] Seeds for categories and initial platforms/ad types

- [ ] Task 2: Build Console CRUD interface for PR catalogs
  - [ ] Console::PrCategoriesController (index, new, create, edit, update, destroy)
  - [ ] Console::MediaPlatformsController (index, new, create, edit, update, destroy)
  - [ ] Console::OutdoorAdTypesController (index, new, create, edit, update, destroy)
  - [ ] Routes: nested under console or as top-level resources
  - [ ] Views: Reuse Story 0.4 catalog-editor pattern + TailAdmin styling

- [ ] Task 3: Add authorization & soft-delete
  - [ ] Pundit policies for catalog admin access (console-only)
  - [ ] SoftDeletable concern on all three models
  - [ ] Soft-delete tests to ensure retired catalogs don't appear in dropdowns

- [ ] Task 4: Sidebar navigation for PR module
  - [ ] Add "PR" sidebar item in org-side navigation
  - [ ] Nested category links: show 6 PR categories as filter links
  - [ ] Style matches Kitchen Cabinet/Cadre Program sidebars

- [ ] Task 5: Tests & verification
  - [ ] Model tests: validations, associations
  - [ ] Console CRUD tests: create, read, update, soft-delete
  - [ ] Integration test: seed catalogs, verify in console, verify sidebar shows categories
  - [ ] Soft-delete test: archived catalogs don't appear in active dropdowns
  - [ ] `bin/rails test` + `bin/rubocop` green

## Dev Notes

- **Reuse Story 0.4 pattern:** Console::PrCategoriesController should mirror Story 0.4's (TicketCategoriesController)[/reference-data-catalog-editor], using the same CRUD + soft-delete pattern.
- **Six seeded categories:** PR system is built around exactly 6 categories defined in the story. These are hardcoded in the migration/seed, not user-configurable initially.
- **Media Platforms + Outdoor Ad Types:** These are extensible. Users/operators can add new platforms or ad types as needed. Both should be admin-managed, global catalogs.
- **Sidebar navigation:** PR sidebar will appear in org-side nav (similar to Kitchen Cabinet, Cadre, Ground Reports). The 6 categories become filter links for the PR record list (Story 4.2).
- **Soft-delete:** All catalogs support soft-delete so archived/retired items don't pollute dropdowns but remain in audit history.
- **Global scope:** Unlike Kitchen Cabinet/Cadre/Ground Reports (org-scoped), these are GLOBAL catalogs managed once at platform level. All orgs share the same category list.

## References

- [Story 0.4: Reference Data Catalog Editor] — CRUD + soft-delete pattern to reuse
- [Epic 4 Brief] — FR32, FR33; 6 seeded PR categories
- [Sidebar Navigation Pattern] — See Kitchen Cabinet/Cadre sidebars for style

## Files Being Changed

**New:**
- `app/models/pr_category.rb`
- `app/models/media_platform.rb`
- `app/models/outdoor_ad_type.rb`
- `app/controllers/console/pr_categories_controller.rb`
- `app/controllers/console/media_platforms_controller.rb`
- `app/controllers/console/outdoor_ad_types_controller.rb`
- `app/policies/console/pr_category_policy.rb`
- `app/policies/console/media_platform_policy.rb`
- `app/policies/console/outdoor_ad_type_policy.rb`
- `app/views/console/pr_categories/` (index, new, edit)
- `app/views/console/media_platforms/` (index, new, edit)
- `app/views/console/outdoor_ad_types/` (index, new, edit)
- `db/migrate/[timestamp]_create_pr_catalogs.rb`
- `db/seeds/pr_catalogs.rb` (or inline in main seeds.rb)
- `test/models/pr_category_test.rb`
- `test/models/media_platform_test.rb`
- `test/models/outdoor_ad_type_test.rb`
- `test/integration/console_pr_catalogs_test.rb`

**Updated:**
- `app/views/ui/_sidebar.html.erb` — Add PR nav item + 6 category filter links
- `config/routes.rb` — Add PR catalog routes to console namespace

## Change Log

| Date | Change |
|------|--------|
| 2026-10-08 | Story 4.1 drafted — PR catalogs (pr_categories, media_platforms, outdoor_ad_types). Reuses Story 0.4 catalog-editor pattern. Global scope, Admin-managed from Console. 6 seeded PR categories drive sidebar navigation. Status → ready-for-dev. |

## Status

ready-for-dev
