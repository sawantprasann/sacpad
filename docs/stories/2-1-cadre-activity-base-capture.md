---
story_key: 2-1-cadre-activity-base-capture
epic: 2
depends_on: 0-14-shared-chrome-export-dashboard
baseline_commit: 597d5ae7d31f9b1d6ae955812cf3381da3a873e2
---

# Story 2.1: Cadre activity base capture

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user with Cadre Program write access,
I want to log an activity with its common fields and photos,
so that cadre work is captured consistently across categories.

## Acceptance Criteria

1. Given a user with Cadre Program access, when they create an activity, then a `cadre_activities` row is created with `owner` (the creating user), `organization` (the request tenant), a category from the six fixed values, `impact_notes` (the long-form "Media Value" note), photos via Active Storage, and soft-delete columns (`discarded_at`, `discarded_by_id`) (FR24).
2. The category is a fixed enum, not an Admin-extensible catalog. There is no Console editor and no `cadre_categories` table (FR24).
3. The record is organization-scoped and viewer-subtree-scoped: Org A cannot read, update, or delete an Org B row (isolation test, expect not-found); a peer outside the viewer's subtree does not appear in the list and 404s on show (FR11, FR24).
4. A role with `cadre_program` `read` can open the list and a record in their subtree, and cannot create (404, not 403). A role with no `cadre_program` access sees no nav entry and is redirected from the module URL.
5. The capture form is mobile-first, labels the note **Media Value**, accepts multiple photos, and uses touch targets ≥44px (UX-DR14). The rendered form posts `cadre_activity[...]`.

## Tasks / Subtasks

- [x] Task 1: `CadreProgram::CadreActivity` model + migration (AC: 1, 2, 3)
  - [x] Migration `create_table :cadre_activities` (timestamp after `20261006130000`). Columns: `owner_id` (NOT NULL, FK → `users`), `organization_id` (NOT NULL, FK), `category` integer NOT NULL, `impact_notes` text nullable, `discarded_at`, `discarded_by_id`, timestamps. Indexes: `discarded_at`, `category`, `[organization_id, owner_id]`.
  - [x] Model `app/models/cadre_program/cadre_activity.rb`. `self.table_name = "cadre_activities"`. `include OrganizationScoped` and `include SoftDeletable`. `belongs_to :owner, class_name: "User"`. `has_many_attached :photos`.
  - [x] Integer enum, explicit map, append-only, never reorder:

    ```ruby
    enum :category, {
      program_by_party: 0,
      leadership_meets: 1,
      party_programs_hosted: 2,
      personal_program: 3,
      personal_activities: 4,
      one_to_one: 5
    }
    ```

  - [x] `CATEGORY_LABELS` for the UI (do not rely on `humanize`): "Program By Party", "Leadership Meets", "Party Programs Hosted", "Personal Program", "Personal Activities", "One To One".
  - [x] `validates :category, presence: true`. `impact_notes` and photos are optional. Do **not** `include FullyVersioned`.
- [x] Task 2: Routes, controller, capture + scoped list (AC: 1, 3, 4, 5)
  - [x] `namespace :cadre_program { resources :activities, only: %i[index new create show] }` in `config/routes.rb`.
  - [x] `CadreProgram::ActivitiesController < ApplicationController`. `before_action :authenticate_user!` and a module gate that redirects to `root_path` when `!current_user.role.can_access?("cadre_program")` (same shape as `require_kitchen_cabinet_access`).
  - [x] `index`: `policy_scope(CadreProgram::CadreActivity)`, optional `?category=` when `CadreActivity.categories.key?(params[:category])`, `order(created_at: :desc, id: :desc)`, `pagy(:offset, relation)`. Also `authorize CadreProgram::CadreActivity`.
  - [x] `show`: `policy_scope(...).find(params[:id])` then `authorize`. Out of scope → `RecordNotFound` → 404.
  - [x] `new` / `create`: `owner = current_user`. Never assign `organization_id` from params (acts_as_tenant sets it). Permit only `:category`, `:impact_notes`, `photos: []`. On success `record_activity("cadre_activity.created", record: @activity)` then redirect to the show page. On failure `render :new, status: :unprocessable_entity`.
- [x] Task 3: Policy (AC: 3, 4)
  - [x] `app/policies/cadre_program/cadre_activity_policy.rb` — class `CadreProgram::CadreActivityPolicy < ApplicationPolicy`. Copy `KitchenCabinet::TicketPolicy` with the module string swapped. `index?` must not touch `record` (Pundit passes the class on `authorize CadreProgram::CadreActivity`):

    ```ruby
    def index?  = user.role.can_access?("cadre_program")
    def show?   = index? && record.owner_id.in?(user.subtree_user_ids)
    def create? = user.role.can_write?("cadre_program")
    def new?    = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.kept.where(owner_id: user.subtree_user_ids)
      end
    end
    ```

  - [x] No `update?` / `destroy?` in this story (no edit or delete UI). Do not query with a bare `CadreActivity.where`.
- [x] Task 4: Sidebar + mobile-first form (AC: 2, 4, 5)
  - [x] In `app/views/ui/_sidebar.html.erb`, pull **Cadre Program** out of the "soon" loop. One link to `cadre_program_activities_path`, gated on `can_access?("cadre_program")`, using the existing `menu-item` / `menu-item-active` classes. No category submenu (categories are an enum, not a catalog). The other five modules stay "soon". Kitchen Cabinet is unchanged.
  - [x] `activities/new.html.erb`: single column, `max-w-xl`, `form_with model: @activity, scope: :cadre_activity, url: cadre_program_activities_path, multipart: true`. Category `<select>` of the six labels, textarea labeled **Media Value**, `file_field :photos, multiple: true, accept: "image/*"`. Fields and submit use `min-h-11`. Reuse `ta_card_classes`, `ta_label_classes`, `ta_field_classes`, `ta_btn_primary`, `ta_btn_secondary`.
  - [x] `index`: scoped rows (category label, Media Value excerpt, photo count, created date, owner). Empty state: "No cadre activity yet." Party-accented control to log an activity (`style` via `--org-party-color` / `--org-party-contrast`, same as the Kitchen Cabinet FAB) shown only when `can_write?("cadre_program")`.
  - [x] `show`: the base fields and attached photos. No detail-section placeholders that look like a finished per-category form.
- [x] Task 5: Tests + verify (AC: all)
  - [x] `test/models/cadre_program/cadre_activity_test.rb`: `OrganizationScoped` + `SoftDeletable` ancestors, frozen category integer map, category required, photos attach, `assert_raises_without_tenant`, `assert_tenant_isolated`.
  - [x] `test/integration/cadre_program_activities_test.rb`: rendered form contains `name="cadre_activity[category]"` (do not trust a direct POST alone); create sets owner from the session and ignores a posted `organization_id`; read-only create → 404; subtree list hides a peer's row; peer show → 404; successful create writes `ActivityLog` action `cadre_activity.created`.
  - [x] `test/integration/cadre_program_nav_test.rb`: permitted user sees a Cadre Program link and no "soon" badge on that item; no-access user sees no link and is redirected from `cadre_program_activities_path`; Ground Reports / PR / Social Media / Voter Lists / RAG Mapping still say "soon".
  - [x] `bin/rails test` green (baseline 143 runs / 0 failures — only add). `bin/rubocop` 0 offenses. No new gems.

## Dev Notes

- **This story is the base row only.** Story 2.2 adds the five detail tables and the category-specific fields. Story 2.3 adds the dashboard widget body and Excel/chart export. A 2.1 activity is valid with category + optional Media Value + optional photos and **no** detail row.
- **Why a list and a show page are in 2.1:** the user has to reach capture from the sidebar and confirm what they saved. The list is `policy_scope` over the base table, paginated. It is the relation Story 2.3 will export. Do not add `format.xlsx`, a chart, or `app/views/cadre_program/_dashboard_widget.html.erb`. The dashboard already registers `{ title: "Recent cadre activity", mod: "cadre_program" }` in `dashboard_widgets_for` and renders the generic "Populated by its module epic." line until that partial exists. Leave `application_helper.rb` and `ui/_dashboard_widget.html.erb` alone.
- **Do not install Action Text.** Rails 8.1 Action Text is still Trix plus an `action_text_rich_texts` table (`has_rich_text`), and `rails action_text:install` also tries to add Active Storage tables that already exist. The brief's "rich text" means a long-form narrative labeled Media Value, kept distinct from each future detail table's operational `notes` — the same wording used for `VillageYatra.notes` ("rich text/text area"). Store `impact_notes` as `t.text` and render a textarea. Precedent: `Ticket.description`.
- **Fixed enum, not a catalog.** `TicketCategory` is global reference data with a Console editor because new ticket categories need no new columns. A seventh cadre category always needs a new detail table, so the six names live in code. Do not subclass `Console::ReferenceController`. Do not seed a categories table. `program_by_party` and `personal_program` stay **separate enum values** even though Story 2.2 will point both at one `CadreActivityProgram` shape.
- **Namespacing checklist (Epic 1 retro — this is how 1.2 almost shipped a broken form):**
  - Pin `self.table_name = "cadre_activities"`. `CadreProgram::CadreActivity` would otherwise look for `cadre_program_cadre_activities`.
  - `belongs_to :owner, class_name: "User"`.
  - `form_with` on this model param-keys as `cadre_program_cadre_activity` unless `scope: :cadre_activity` is set. Controller is `params.require(:cadre_activity)`. Assert the rendered `name=` attribute.
- **Tenant and subtree.** `include OrganizationScoped` → `acts_as_tenant(:organization)` and `organization_id` presence. `ApplicationController#set_current_organization` already sets the tenant to `current_user.organization`. A missing tenant raises `ActsAsTenant::Errors::NoTenantSet`. Strong params must not permit `:owner_id`, `:organization_id`, `:discarded_at`, `:discarded_by_id`. `Pundit::NotAuthorizedError` is already rescued to 404 in `ApplicationController`. Subtree ids come from `user.subtree_user_ids` (closure_tree, Story 0.9).
- **Audit.** `CadreActivity` is not a confirmed Tier-1 PaperTrail model (brief §7a: Ticket is Tier 2; Tier 1 confirmed for Voter, User, RolePermission). Do not add a `CadreActivityVersion` or `include FullyVersioned`. Do call `record_activity("cadre_activity.created", record: @activity)` on successful create — `Auditable` is already included on `ApplicationController`; today only Console org views call it, and architecture requires mutations to write `ActivityLog` (`resource.verb`). No activity-log UI.
- **Soft delete.** Columns + `SoftDeletable` (`Discard::Model`, so `kept` exists) belong on the model now. No delete button in this story.
- **Photos.** `has_many_attached :photos` (the brief's name for this model; tickets use `:attachments`). Active Storage and `image_processing` are already installed. Reuse `test/fixtures/files/photo.png`. Dev storage is disk; do not configure S3.
- **What must keep working:** Kitchen Cabinet routes, sidebar submenu, ticket capture, dashboard widgets (including the cadre placeholder), the other "soon" modules, and the full existing suite.

### Project Structure Notes

- New: `db/migrate/<ts>_create_cadre_activities.rb`, `app/models/cadre_program/cadre_activity.rb`, `app/policies/cadre_program/cadre_activity_policy.rb`, `app/controllers/cadre_program/activities_controller.rb`, `app/views/cadre_program/activities/{index,new,show}.html.erb`, `test/models/cadre_program/cadre_activity_test.rb`, `test/integration/cadre_program_activities_test.rb`, `test/integration/cadre_program_nav_test.rb`.
- Modify: `config/routes.rb`, `app/views/ui/_sidebar.html.erb`, `db/schema.rb` (via migrate).
- Do not modify: `app/helpers/application_helper.rb`, `app/views/ui/_dashboard_widget.html.erb`, Kitchen Cabinet files, Console controllers, `Gemfile`.

### Architecture compliance

- Org-facing namespace at the clean root: `namespace :cadre_program` (architecture routes). No JSON API. No Console surface.
- Every read goes through `policy_scope` inside the tenant. Every action calls `authorize` or `policy_scope`. Cross-tenant and not-permitted → 404.
- Domain table carries NOT NULL FK `organization_id` plus soft-delete columns. Model includes `OrganizationScoped`.
- Reuse `ui/` helpers and the party-accent CSS variables. No new chrome, no React, no party color on full surfaces.
- Minimal Hotwire: a normal form POST. No Stimulus controller, no Turbo Stream.

### Library and framework requirements

- Stay on the pinned stack. Do not `bundle add`. Relevant pins already in the Gemfile: Rails `~> 8.1.4`, `acts_as_tenant ~> 2.0`, `discard ~> 2.0`, `pundit ~> 2.5`, `pagy ~> 43.7`, `closure_tree ~> 9.8`.
- Enum syntax must match `KitchenCabinet::Ticket`: `enum :category, { key: integer }`. Rails 8.1 also accepts keyword form; do not use an array enum (order-derived integers). Rails 8.1.0+ eagerly validates enum values.
- Pagination is pagy 43: `include Pagy::Method` is already on `ApplicationController`; call `pagy(:offset, relation)`. There is no `Pagy::Backend`.
- Active Storage: `has_many_attached :photos`. Multiple upload param is `photos: []`.
- Action Text / Trix: not in this app. Do not install (Rails 8.1 guide still installs Trix and `action_text_rich_texts`).

### Testing requirements

- Minitest, same style as `test/models/kitchen_cabinet/ticket_test.rb` and `test/integration/kitchen_cabinet_browse_test.rb`.
- Isolation helpers: `require_relative "../../support/tenant_isolation"` and `include TenantIsolation`. Build the foreign row inside `ActsAsTenant.without_tenant` (or `with_tenant` of org B). `assert_tenant_isolated(CadreActivity, owner: @org_a, foreign_record: @b_activity)` and `assert_raises_without_tenant(CadreActivity)`.
- Subtree fixture shape from the browse test: one org, `@root`, `@alice` and `@bob` both `parent: @root`. Alice's index shows her row and not Bob's. Alice's `GET` of Bob's show is 404.
- Module permission strings are `"cadre_program"` with access levels `"read"` / `"write"` / absent. `Role::MODULES` already includes `cadre_program`. System roles from seeds already have write; tests should build their own roles so they don't depend on seed state.
- The form test must `assert_select` (or `assert_match`) the rendered input name `cadre_activity[category]`. A test that only `post`s `cadre_activity: { ... }` will not catch a missing `scope:`.
- Run `bin/rails test` and `bin/rubocop`. Do not skip either.

### Epic 1 intelligence (no prior Epic 2 story)

- Story 1.2 completion: namespaced `form_with` silently mismatched params; the rendered-field assertion caught it, the POST did not. Repeat that assertion here.
- Story 1.3: `policy_scope` = org (acts_as_tenant) ∩ `owner_id` in `subtree_user_ids` ∩ `kept`. Copy `KitchenCabinet::TicketPolicy`, swapping the module string to `"cadre_program"`.
- Story 1.1: Kitchen Cabinet got a category submenu because categories are data. Cadre gets a single link. Do not copy the submenu.
- Epic 1 retro (`docs/stories/epic-1-retro-2026-10-06.md`): pin `table_name`, explicit `class_name`, `form_with scope:`; do not add unpinned gems; widget partial + `export_url` are Story 2.3, not this one. Chartkick still has no JS adapter — another reason not to add a chart here.
- `Ticket` deliberately does not include `FullyVersioned`. Follow that for `CadreActivity`.

### Git intelligence

Recent `main` commits (HEAD `597d5ae`): gem pinning + sprint board + Epic 1 retro, then Stories 1.8 → 1.3 (widget/export, closure, voter gate, follow-ups, status, pagy 43, browse). Patterns to copy: one model + one policy + one namespaced controller, integration tests that sign in with Devise and build orgs via `ActsAsTenant.without_tenant`, party-accent FAB using CSS variables, `min-h-11` fields. Do not restack Kitchen Cabinet.

### Latest technical notes

- Rails **8.1.3.1** enum API: explicit integer hash; array form derives integers from position (unsafe if a value is inserted). Keyword and hash forms both exist; this codebase uses the hash form with an optional `default:`.
- Rails 8.1 Active Storage `has_many_attached` stores rows in the existing `active_storage_attachments` / `active_storage_blobs` tables. Renaming the model later requires updating `record_type`. Name the class `CadreProgram::CadreActivity` now and keep it.
- Rails 8.1 Action Text is Trix + `has_rich_text` (no column on the owner table). Rejected for this story; see Dev Notes.

### Project context

No `project-context.md` in the repo. Planning sources are `docs/epics.md`, `docs/architecture.md`, `docs/project_brief.md` §6.2, and `docs/prds/prd-sacpad-2026-10-04/prd.md` §4.4. Implementation artifacts live in `docs/stories/`. Sprint tracking is `docs/stories/sprint-status.yaml`.

### References

- [Source: docs/epics.md#Story-2.1] — AC; Epic 2 objective; Stories 2.2 and 2.3 boundaries.
- [Source: docs/project_brief.md §6.2] — base columns, six category names, why not six tables or one wide table, why the category list is not Admin-extensible. Data dictionary line for `CadreActivity`.
- [Source: docs/prds/prd-sacpad-2026-10-04/prd.md#FR-24] — write permission, shared base vs per-category fields. FR-25 and FR-26 are Stories 2.2 and 2.3.
- [Source: docs/architecture.md] — `namespace :cadre_program { resources :activities }`; `cadre_program/` model, controller, and policy paths; tenancy rule; 404 not 403; `organization_id` NOT NULL.
- [Source: docs/stories/epic-1-retro-2026-10-06.md] — namespaced-model checklist; do not add gems; widget/export deferred.
- [Source: app/models/kitchen_cabinet/ticket.rb] — `table_name`, `OrganizationScoped`, `SoftDeletable`, enum hash, `has_many_attached`.
- [Source: app/policies/kitchen_cabinet/ticket_policy.rb] — subtree `Scope`.
- [Source: app/controllers/kitchen_cabinet/tickets_controller.rb] — module gate, owner from `current_user`, `pagy(:offset, relation)`, strong params.
- [Source: app/views/kitchen_cabinet/tickets/new.html.erb] — `scope: :ticket` comment and `min-h-11` fields. Copy the scope discipline, not the ticket fields.
- [Source: app/views/ui/_sidebar.html.erb] — KC gate + the "soon" loop this story splits.
- [Source: app/controllers/concerns/auditable.rb] — `record_activity`.
- [Source: test/support/tenant_isolation.rb] — release-gate helpers.
- [Source: test/integration/kitchen_cabinet_browse_test.rb] — root / alice / bob subtree fixture.

## Dev Agent Record

### Agent Model Used

Grok 4.7 (BMad dev-story)

### Debug Log References

- Model tests failed first with `uninitialized constant CadreActivity`, then passed after the model and migration.
- `bin/rails test` → 158 runs / 605 assertions / 0 failures (was 143). `bin/rubocop` → 139 files, 0 offenses.
- Signed-in request against the running dev server: empty list, form posts `cadre_activity[...]` with Media Value, create redirects to show, show and list render the saved activity, Kitchen Cabinet still loads.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- `CadreProgram::CadreActivity` on `cadre_activities`: fixed integer enum (six categories), optional `impact_notes` textarea labeled Media Value, `has_many_attached :photos`, `OrganizationScoped` + `SoftDeletable`. No Action Text, no PaperTrail, no detail tables.
- Capture is `index` / `new` / `create` / `show`. Owner comes from the session; organization from the tenant. Reads go through `policy_scope` (org ∩ subtree ∩ kept). Read-only create is 404. No module access redirects home. Successful create writes `ActivityLog` `cadre_activity.created`.
- Sidebar: Cadre Program is a single gated link. The other five modules stay "soon". Kitchen Cabinet is unchanged. No dashboard widget partial and no Excel export (Story 2.3).
- Form uses `scope: :cadre_activity`. The integration test asserts the rendered field name, not only a direct POST.

### File List

- `db/migrate/20261007100000_create_cadre_activities.rb` (new)
- `db/schema.rb` (modified — cadre_activities)
- `app/models/cadre_program/cadre_activity.rb` (new)
- `app/policies/cadre_program/cadre_activity_policy.rb` (new)
- `app/controllers/cadre_program/activities_controller.rb` (new)
- `app/views/cadre_program/activities/index.html.erb` (new)
- `app/views/cadre_program/activities/new.html.erb` (new)
- `app/views/cadre_program/activities/show.html.erb` (new)
- `app/views/ui/_sidebar.html.erb` (modified — Cadre Program link)
- `config/routes.rb` (modified — cadre_program activities)
- `test/models/cadre_program/cadre_activity_test.rb` (new)
- `test/integration/cadre_program_activities_test.rb` (new)
- `test/integration/cadre_program_nav_test.rb` (new)
- `docs/stories/sprint-status.yaml` (modified — story status)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-07 | Story 2.1 drafted (BMad create-story) — Cadre Program base capture: `CadreProgram::CadreActivity` (fixed six-value enum, Media Value text, Active Storage photos, soft-delete), subtree/org policy, mobile-first form, sidebar entry. Detail tables (2.2) and widget/export (2.3) left out. Status → ready-for-dev. |
| 2026-10-07 | Story 2.1 implemented (BMad dev-story) — base model, subtree policy, capture form, scoped list/show, sidebar entry, activity log on create. 15 new tests; full suite 158/0, rubocop clean. Status → review. |

## Status

review
