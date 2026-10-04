---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-10-04'
inputDocuments:
  - docs/prds/prd-sacpad-2026-10-04/prd.md
  - docs/prds/prd-sacpad-2026-10-04/addendum.md
  - docs/ux-designs/ux-sacpad-2026-10-04/DESIGN.md
  - docs/ux-designs/ux-sacpad-2026-10-04/EXPERIENCE.md
  - docs/epics.md
  - docs/project_brief.md
workflowType: 'architecture'
project_name: 'SAC-PAD'
user_name: 'Pinkal'
date: '2026-10-04'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:** 54 FRs across 12 feature groups (9 epics, 51 stories). Architecturally they collapse into: (a) a secure multi-tenant foundation + hierarchical RBAC + Platform Console (FR1–18), (b) seven domain modules sharing one chrome/scoping/audit/export substrate (FR19–47), and (c) cross-cutting shell/dashboard/audit frameworks (FR48–54). The dominant architectural force is that every module is a thin domain layer over the same organization → module-permission → subtree scoping pattern.

**Non-Functional Requirements:** 27 NFRs. The shaping ones:
- Security/isolation (NFR1–5): defense-in-depth tenant isolation, release-blocking isolation test suite, auth hardening, pre-launch pen test.
- Scale for 10k concurrent (NFR6–17): horizontal app tier, connection pooling, separate job/cache/cable DBs, read replicas, subtree caching, precomputed rollups, pagination, deliberate indexing, CDN, independent job tier, observability.
- Data governance (NFR18–20): PII encryption at rest, soft-delete only, encrypted tokens.
- Integrations (NFR21–23): idempotent Meta sync, vendor-agnostic boundaries, rate limits.
- Compliance (NFR24–25): DPDP/election-comms review, consent/opt-in before send.

### Scale & Complexity

- Primary domain: full-stack web (Rails 8 modular monolith + TailAdmin; mobile-first responsive org side, desktop operator Console)
- Complexity level: enterprise
- Estimated architectural components: two Devise scopes; a Pundit + acts_as_tenant + closure_tree authorization core; ~40 domain models across 7 modules; an async/integration tier (Meta/WhatsApp/IVRS); an audit/versioning subsystem; a precomputed-rollup subsystem; a widget-composed dashboard + per-org theming layer.

### Technical Constraints & Dependencies

- Stack is pre-decided (PRD addendum): Rails 8, PostgreSQL, TailAdmin, Devise ×2, Pundit, closure_tree, acts_as_tenant, discard, paper_trail (custom per-model version classes), Solid Queue/Cache/Cable on separate DBs, Active Storage + CDN, PgBouncer, Chartkick, caxlsx/roo, Pagy, Bullet, Datadog.
- External dependencies (vendor TBD): Meta Graph API; WhatsApp BSP or Cloud API; IVRS vendor.
- Hard constraint: no cross-tenant leakage; `Admin` is a separate account type, never a `User`.
- Open items affecting architecture: OQ-6 (ops-Admin access level), OQ-7 (10k definition → load test), OQ-11 (Voter geography FK vs flat text).

### Cross-Cutting Concerns Identified

1. Tenant isolation (4 layers + RLS for Voter) — spans every model/controller/policy.
2. Hierarchical authorization (closure_tree subtree scoping + caching) — every read path.
3. Audit & versioning (two tiers + ActivityLog) — every mutating action.
4. Scalability topology (pooling, replicas, job tier, precompute) — deployment-wide.
5. Shared UI substrate (chrome, export, dashboard widgets, per-org theming) — every surface.
6. Integration & async boundary (Meta/WhatsApp/IVRS, rate limits, idempotency) — Epic 5 + daily sync.
7. PII & compliance (encryption, logged access, consent) — Voter + bulk-messaging paths.

## Starter Template Evaluation

### Primary Technology Domain

Full-stack **server-rendered web** (Rails 8.1 modular monolith + Hotwire), not an SPA. Mobile-first responsive org side + desktop operator Console. Stack pre-decided in the PRD addendum; this step ratifies current versions and the TailAdmin integration path.

**Verified versions (web, Oct 2026):** Rails **8.1.x** is the current stable line (8.1.3.1; security support to Oct 2027). `tailwindcss-rails` **v4.4.x** supports **Tailwind CSS v4** (CSS-first config, LightningCSS — no PostCSS/autoprefixer) on Rails 8.1 + Propshaft. **TailAdmin 2.4.0** ships React/Next/Vue/Angular/Laravel/HTML builds — **no Rails build** — so the Rails integration ports TailAdmin's framework-agnostic **HTML/Tailwind** components into ERB partials.

### Starter Options Considered

- **`rails new .` (Rails 8.1) + Hotwire + Propshaft + tailwindcss-rails (Tailwind v4) + TailAdmin HTML port** — SELECTED. Rails' own generator is the "starter"; no third-party boilerplate. Brings Turbo/Stimulus, Solid Queue/Cache/Cable, import maps out of the box.
- **TailAdmin React/Next.js build** — REJECTED. Forces an SPA + Node pipeline against a server-rendered Rails app; the brief/PRD assume Rails + Hotwire.
- **TailAdmin Laravel build** — REJECTED (wrong framework; confirms the Rails route uses the HTML variant).

### Selected Starter: `rails new .` (Rails 8.1) + TailAdmin HTML/Tailwind port

**Rationale:** The stack is fixed; lowest-risk path is Rails' first-party generator + official `tailwindcss-rails` (Tailwind v4), porting TailAdmin's HTML/Tailwind components into reusable ERB partials (the shared chrome, UX-DR1/UX-DR2). One rendering model (Hotwire), one asset pipeline (Propshaft), no Node build.

**Initialization Command (Story 0.1) — generate IN PLACE in the existing project folder:**

```bash
# Run FROM the existing sacpad/ folder (already a git repo). Do NOT create a new subfolder.
rails new . --database=postgresql --css=tailwind --skip-jbuilder --skip-git
# --skip-git: repo already initialized; don't re-init git or clobber .gitignore.
# Existing docs/ (planning artifacts) are preserved; resolve any direct file collision
# (e.g. .gitignore/README) by keeping/merging, never blind-overwriting.
# Then: configure Solid Queue/Cache/Cable on SEPARATE databases (config/database.yml),
#       add gems (devise, pundit, closure_tree, acts_as_tenant, discard, paper_trail,
#       pagy, chartkick, caxlsx, roo, bullet, faraday), and port TailAdmin HTML/Tailwind
#       components into app/views shared partials under a ui/ namespace.
```

**Architectural decisions provided by the starter:**

- **Language & Runtime:** Ruby (current 3.x) + Rails 8.1.x.
- **Styling:** Tailwind CSS v4 via `tailwindcss-rails` v4.4.x (CSS-first, LightningCSS); TailAdmin HTML ported to ERB. No PostCSS/autoprefixer, no Node SPA build.
- **Front-end interactivity:** Hotwire (Turbo + Stimulus) — server-rendered, progressive.
- **Asset pipeline:** Propshaft + import maps.
- **Background/async:** Solid Queue (jobs), Solid Cache (cache), Solid Cable (websockets) — each on a separate database from primary OLTP (NFR8).
- **Testing/Lint:** Rails default test stack + Bullet (dev/staging) for N+1; RuboCop.
- **Code organization:** standard Rails MVC + Pundit policies + service objects for integration/async boundaries; TailAdmin partials under a shared `ui/` namespace.

**Note:** Project initialization using this command is the first implementation story (Story 0.1 in docs/epics.md), run in-place in the existing folder.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical (block implementation):**
- Tenant-isolation layering + `Admin`-outside-tenancy model
- Two Devise scopes & controller namespacing (`/` vs `/console`)
- closure_tree subtree-scoping + caching contract
- Data store = PostgreSQL; file store = S3 via Active Storage

**Important (shape the architecture):**
- Minimal-Hotwire interactivity posture (maintainability guardrail)
- Two-tier audit/versioning + ActivityLog as reusable concerns
- Vendor-agnostic integration/async boundary (Meta/WhatsApp/IVRS)
- Precomputed-rollup subsystem (RAG, reach)

**Deferred (post-decision / later):**
- Voter geography → FK migration (flat text in v1; OQ-11)
- WhatsApp/SMS & IVRS vendor selection (OQ-4)
- App-tier cloud confirmed as AWS pending final ops sign-off (only S3 firm)

### Data Architecture

- **Database:** PostgreSQL (managed — assume AWS RDS/Aurora). Single primary OLTP DB.
- **Separate databases** for Solid Queue / Solid Cache / Solid Cable (NFR8).
- **Read replica(s)** for heavy-read paths (dashboards, exports, Voter lookups) (NFR9).
- **Connection pooling:** PgBouncer (transaction mode) in front of Postgres (NFR7).
- **Data modeling:** single Rails app, **namespaced modules** (not Rails engines) sharing one scoping/audit/export substrate. ~40 domain models; every domain table carries a denormalized, NOT NULL, FK-constrained `organization_id`.
- **Voter geography:** flat text for state/loksabha/assembly/village in v1; `booth_id` the only FK (OQ-11 deferred).
- **File storage:** Active Storage → **S3** for all file types (photos/videos/attachments/docs), **CDN (CloudFront) in front**; never served through the app (NFR14).
- **Caching:** Solid Cache; cache each user's `subtree_ids` (invalidated only on hierarchy change) (NFR10).
- **Migrations:** standard Rails migrations; reference-data seeds (geography, parties, categories) via seed tasks.

### Authentication & Security

- **Authentication:** Devise, **two scopes** — `devise_for :users, path: ''` (org-facing) and `devise_for :admins, path: 'console'` (operator). Module sets per PRD/addendum; no self-service sign-up; no `recoverable` on `Admin`. 2FA deferred to Phase 2.
- **`Admin` is a separate account type**, never a `User`; never runs through tenant-scoped query machinery — its Console queries are explicit and logged, not a bypass flag.
- **Authorization:** Pundit policies, scoped by `organization → module-permission → subtree`. Roles are data (`roles`/`role_permissions`), Admin-defined only.
- **Tenant isolation = four independent layers:** (1) Pundit per-action scope; (2) denormalized `organization_id`; (3) `acts_as_tenant` model-layer net that RAISES on an unscoped query; (4) DB `NOT NULL` + FK. Plus **Postgres RLS on the `Voter` table** in v1 (session GUC carries current org) as a DB-enforced 5th layer on the most sensitive PII.
- **`ops`-tier Admin:** full-equivalent access within assigned orgs (incl. soft-delete) **minus** platform-wide settings and role definition; every cross-org access logged (OQ-6 resolved).
- **Isolation tests** are a release gate: Org-A-cannot-touch-Org-B (expect 404) for every model (NFR3).
- **Encryption:** Active Record Encryption for Voter PII and stored external tokens, at rest (NFR18/20).
- **Auth hardening:** rate-limiting (rack-attack-class) + account lockout on both scopes (NFR4).

### API & Communication Patterns

- **No public JSON API in v1** — server-rendered Hotwire app; one rendering/auth/scoping surface (a deliberate isolation-risk reduction).
- **External integrations behind vendor-agnostic service objects:** Meta Graph API (Faraday, Batch API, no wrapper gem); WhatsApp (BSP/Cloud API, TBD); IVRS (vendor TBD). Each adapter is swappable; the schema stays vendor-neutral (NFR22).
- **Async boundary:** Solid Queue; one job per bulk-post/message target; idempotent daily sync; per-target status + individual retry; respects provider rate limits (NFR21/23).
- **Error handling:** per-target error capture (status + message) rather than whole-batch failure; surfaced in the live status view and the health console.

### Frontend Architecture

- **Server-rendered Rails + TailAdmin (HTML port) + Tailwind v4.** No SPA, no Node build.
- **Minimal-Hotwire posture (maintainability guardrail):** plain ERB by default; **Turbo Drive on** (free, automatic); **Turbo Streams/Stimulus used ONLY where interactivity is required** — the bulk-post live status (Turbo Streams over Solid Cable), the voter-gate lock/unlock, the sentiment segmented control, the mobile FAB/bottom-sheets, chart toggles. No speculative JavaScript; a new contributor should find mostly boring server-rendered views.
- **Shared UI substrate:** chrome (top bar/sidebar/toolbar/table), export, and the dashboard widget-composition framework are built once (Epic 0) as reusable partials under a `ui/` namespace.
- **Per-org party theming:** resolved at login from `Party.color`+logo; applied as a bounded **accent only** (AA-safe foreground computed); reserved RAG palette never overridden; Console never themed.
- **Pagination:** Pagy on every listing (NFR12).

### Infrastructure & Deployment

- **Hosting:** assume AWS (app on a container runtime — ECS/EKS or EC2 behind a load balancer; RDS/Aurora Postgres; CloudFront + S3). *Only S3 for storage is firm; app-tier cloud pending final ops sign-off.*
- **Horizontal app tier**, autoscaled on CPU/latency; **independent job-worker tier** so the bulk-publish fan-out can't starve exports (NFR6/15).
- **Observability from day one:** Datadog APM + Postgres slow-query logging (NFR16).
- **Load test** (k6/Locust) against the clarified 10k-concurrent usage shape before launch — gated on resolving OQ-7 (NFR17, Epic 8).
- **Precomputed rollups:** RAG/reach computed by background jobs into queryable tables, read by dashboards (never live-aggregated) (NFR11).

### Decision Impact Analysis

**Implementation sequence (maps to epics.md):**
1. Scaffold + multi-DB + isolation spine + two Devise scopes (Epic 0 Stories 0.1–0.3)
2. Reference data + org lifecycle + users + roles + hierarchy/subtree cache (0.4–0.9)
3. Audit/soft-delete + logged Admin access + Politician roster + health + shared shell + Voter primitive (0.10–0.15)
4. Domain modules over the shared substrate (Epics 1–7)
5. Scale/security/compliance verification (Epic 8)

**Cross-component dependencies:**
- The subtree-scoping + `acts_as_tenant` contract is a dependency of EVERY module's policies/queries.
- The audit concern and the shared chrome/export/dashboard framework are dependencies of every module.
- Voter RLS + the `Voter` primitive (0.15) are a dependency of Kitchen Cabinet's sentiment write (1.7) and Voter Lists (Epic 6).
- The integration/async service-object boundary is a dependency of Epic 5 and the daily sync.

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

Rails conventions settle most naming/structure; these rules lock the Rails defaults and add the SAC-PAD-specific patterns where multiple agents could otherwise diverge (tenancy, policies, modules, integrations, Hotwire, audit).

### Naming Patterns

**Database (Rails default):** snake_case plural tables (`tickets`), snake_case columns (`organization_id`), FK `<singular>_id`, index `index_<table>_on_<cols>`. Every domain table includes `organization_id` (NOT NULL, FK) and, where soft-deletable, `discarded_at`/`discarded_by_id`.

**Models:** singular CamelCase (`TicketFollowUp`). Module models are namespaced by feature where it aids clarity, but share the single app (no engines). Enums as Rails `enum` with explicit integer mappings (never reorder; append only).

**Routes/controllers:** org-facing under root path; operator under a `Console::` namespace at `/console`. REST resources, plural (`resources :tickets`). Controllers mirror the namespace (`Console::OrganizationsController`). No public JSON API in v1.

**Code:** standard Ruby — `snake_case` methods/vars, `CamelCase` classes. Service objects are verbs (`Meta::PublishPagePost`, `Bulk::FanOutPost`). Pundit policies `<Model>Policy` with scopes.

**Views/partials:** shared chrome under `app/views/ui/` (e.g. `ui/_module_toolbar.html.erb`, `ui/_status_pill.html.erb`, `ui/_rag_chip.html.erb`). Stimulus controllers kebab-named (`voter-gate`, `sentiment-picker`).

### Structure Patterns

- **Tests:** Rails default `test/` (or `spec/` if RSpec chosen — pick one, lock it). Tenant-isolation tests live in a dedicated `test/isolation/` suite and run in CI as a release gate.
- **Organization:** by Rails layer first (`app/models`, `app/controllers`, `app/policies`, `app/services`, `app/jobs`), feature-namespaced within. Integration adapters under `app/services/<provider>/`.
- **Config:** `config/database.yml` carries the 4 databases (primary + queue/cache/cable); recurring jobs in `config/recurring.yml`; credentials via Rails encrypted credentials (never plaintext).

### Format Patterns

- **Dates/times:** store UTC; display in the org's local context; ISO 8601 in exports.
- **Money/counts:** integers; tabular figures in UI (DESIGN.md `numeric`).
- **Booleans:** real booleans, never 1/0 strings. Enums over free-text status.
- **Null handling:** nullable only where semantically meaningful (e.g. `ended_at` = current).

### Communication Patterns (Hotwire + jobs)

- **Turbo Streams:** target DOM ids via `dom_id(record)`; broadcast channels scoped per org (`"org:#{organization_id}:bulk_post:#{id}"`) so streams never cross tenants.
- **Jobs:** one job per external target (publish/message/call); idempotent; named `<Verb><Noun>Job`. Retries via per-target status + manual retry, not blind requeue.
- **Events/audit:** every mutation writes through the audit concern → `ActivityLog` (`actor`, `action` as `resource.verb` e.g. `ticket.closed`, `record`, `organization`, `at`).

### Process Patterns

- **Tenancy (THE rule):** never write a bare `Model.where(...)`. All reads go through the Pundit policy scope, which runs inside the `acts_as_tenant` current-org context. A query with no tenant set must raise, not return rows. `Admin` Console queries are explicit and separate, always logged.
- **Authorization:** every controller action calls `authorize`/`policy_scope`; a missing authorize fails the request in tests.
- **Errors:** cross-tenant / not-permitted → 404 (never 403 that confirms existence). User-facing errors are plain and specific (EXPERIENCE.md voice); integration errors captured per-target.
- **Loading/empty/locked states:** per EXPERIENCE.md state table (skeletons, empty CTAs, the locked voter-gate helper) — not reinvented per module.

### Enforcement Guidelines

**All agents MUST:** route every read through a Pundit scope inside tenant context; add an isolation test for every new model; include `organization_id` on every domain table; write mutations through the audit concern; keep interactivity to the minimal-Hotwire posture; reuse `ui/` partials rather than new chrome.

**Anti-patterns:** bare `Model.where`/`find` on domain data; a JSON API; a React/Vue component; RAG colors reused for workflow status; party color on full surfaces or the Console; hard deletes; plaintext tokens/PII.

## Project Structure & Boundaries

### Complete Project Directory Structure

```
sacpad/                                  # Rails app generated in place (rails new .)
├── Gemfile                              # rails, devise, pundit, closure_tree, acts_as_tenant,
│                                        # discard, paper_trail, pagy, chartkick, caxlsx, roo,
│                                        # bullet, faraday, aws-sdk-s3, image_processing
├── config/
│   ├── database.yml                     # 4 DBs: primary + queue + cache + cable
│   ├── routes.rb                        # root-path (users) + Console:: namespace (admins)
│   ├── recurring.yml                    # Solid Queue recurring (daily Meta sync, RAG rollup)
│   ├── initializers/
│   │   ├── devise.rb                    # two scopes: users ('') + admins ('console')
│   │   ├── pundit.rb  acts_as_tenant.rb  pagy.rb  paper_trail.rb
│   └── credentials.yml.enc              # S3 keys, Meta app secret, vendor keys (encrypted)
├── app/
│   ├── controllers/
│   │   ├── application_controller.rb    # sets acts_as_tenant current org; Pundit; login tracking
│   │   ├── concerns/{tenant_scoped,auditable_actions}.rb
│   │   ├── dashboard_controller.rb
│   │   ├── kitchen_cabinet/             # tickets, follow_ups, closures
│   │   ├── cadre_program/  ground_reports/  pr/  social_media/  voter_lists/  rag_mapping/
│   │   └── console/                     # OPERATOR namespace (admins only)
│   │       ├── base_controller.rb       # steel skin; logs cross-org access; NO acts_as_tenant
│   │       ├── organizations_controller.rb  onboardings_controller.rb  politicians_controller.rb
│   │       ├── roles_controller.rb  parties_controller.rb
│   │       ├── states_controller.rb  loksabhas_controller.rb  assemblies_controller.rb
│   │       │                                  villages_controller.rb  booths_controller.rb   # geography CRUD
│   │       ├── ticket_categories_controller.rb  pr_categories_controller.rb
│   │       │                                  media_platforms_controller.rb  outdoor_ad_types_controller.rb
│   │       └── audit_logs_controller.rb  platform_health_controller.rb
│   ├── models/
│   │   ├── admin.rb  admin_organization.rb      # separate account type (no org/parent/role)
│   │   ├── organization.rb  party.rb  party_membership.rb  politician.rb
│   │   ├── user.rb  role.rb  role_permission.rb # closure_tree on user; roles-as-data
│   │   ├── concerns/{organization_scoped,soft_deletable,fully_versioned}.rb
│   │   ├── geography/ (state, loksabha, assembly, village, booth)
│   │   ├── kitchen_cabinet/ (ticket, ticket_category, ticket_follow_up, ticket_status_change)
│   │   ├── cadre_program/ (cadre_activity + 5 detail models)
│   │   ├── ground_reports/ (ground_report, testimonial, worship_place, village_yatra,
│   │   │                    village_political_position, *_contact, mock_poll_response)
│   │   ├── pr/ (pr_record, pr_category, media_platform, outdoor_ad_type, *_detail)
│   │   ├── social_media/ (social_page, bulk_post, bulk_post_target, social_page_post,
│   │   │                  influencer, bulk_message, contact_group, ivrs_campaign, ...)
│   │   ├── voter_lists/ (voter)                 # RLS-protected; VoterVersion
│   │   ├── rag_mapping/ (rag_entry)
│   │   └── versions/ (voter_version, user_version, role_permission_version)  # Tier-1
│   ├── policies/
│   │   ├── application_policy.rb        # base: organization → module-permission → subtree
│   │   └── <module>/<model>_policy.rb   # one per model, scope reused everywhere
│   ├── services/
│   │   ├── tenancy/subtree_cache.rb     # cached subtree_ids, invalidated on hierarchy change
│   │   ├── meta/ (connect_page, publish_page_post, fetch_post_insights)  # Faraday adapters
│   │   ├── bulk/ (fan_out_post, send_message)   ivrs/ (launch_campaign)   # vendor-agnostic
│   │   ├── imports/ (base_importer, ground_report_importer, mock_poll_importer, voter_roll_importer)  # roo/creek
│   │   ├── exports/ (excel_export, chart_export)                          # caxlsx
│   │   └── rollups/ (rag_rollup, reach_rollup)
│   ├── jobs/
│   │   ├── publish_page_post_job.rb  send_bulk_message_job.rb  ivrs_call_job.rb
│   │   ├── daily_meta_sync_job.rb (idempotent)  compute_rag_rollup_job.rb
│   │   ├── import_voter_roll_job.rb  import_ground_reports_job.rb        # async bulk uploads
│   ├── javascript/controllers/          # Stimulus: voter_gate, sentiment_picker, fab, chart_toggle
│   └── views/
│       ├── layouts/ (application.html.erb [party-themed], console.html.erb [steel])
│       ├── console/ (organizations, onboardings, roles, parties, states, loksabhas,
│       │             assemblies, villages, booths, ticket_categories, ... )  # catalog CRUD forms
│       ├── voter_lists/imports/  ground_reports/imports/   # upload forms
│       └── ui/ (_top_bar, _module_toolbar, _sidebar, _data_table, _status_pill,
│                _rag_chip, _ticket_card, _voter_gate_field, _sentiment_picker,
│                _console_org_banner, _dashboard_widget, _catalog_editor)
├── db/
│   ├── migrate/  schema.rb  seeds.rb    # geography, parties, system roles, categories seeds
│   └── (queue|cache|cable)_schema.rb
├── test/
│   ├── isolation/                       # RELEASE GATE: A-cannot-touch-B per model (expect 404)
│   ├── models/  policies/  controllers/  services/  system/
│   └── fixtures/
└── docs/                                # EXISTING planning artifacts (untouched by rails new)
    ├── project_brief.md  epics.md  architecture.md
    └── prds/…  ux-designs/…
```

### Routes & URLs (explicit)

**Operator — `Console::` namespace, Devise `:admins` scope, all under `/console` (unadvertised):**
```ruby
devise_for :admins, path: 'console'                      # /console/sign_in
namespace :console do
  root to: 'dashboard#index'
  resources :organizations do
    member { patch :deactivate; patch :reactivate }
    resource :onboarding, only: %i[new create]           # /console/organizations/:id/onboarding (wizard)
    resources :politicians                               # per-org roster
  end
  resources :roles                                       # role & permission catalog
  resources :parties
  resources :states do resources :loksabhas end          # /console/states/:state_id/loksabhas
  resources :loksabhas, only: [] do resources :assemblies end
  resources :assemblies, only: [] do resources :villages end
  resources :villages, only: [] do resources :booths end # geography creation flow
  resources :ticket_categories                           # create TicketCategory HERE
  resources :pr_categories; resources :media_platforms; resources :outdoor_ad_types
  resources :audit_logs, only: %i[index show]
  resource  :platform_health, only: :show
end
```

**Org-facing — Devise `:users` scope, clean root path (`path: ''`):**
```ruby
devise_for :users, path: ''                              # /sign_in
root to: 'dashboard#index'
namespace :kitchen_cabinet do
  resources :tickets do                                  # ?category= filter
    resources :follow_ups, only: %i[create]
    resource  :closure, only: %i[new create]             # 2-step closure + sentiment
  end
end
namespace :cadre_program do resources :activities end
namespace :ground_reports do
  resources :villages, only: %i[index show]
  resources :imports, only: %i[new create]               # BULK EXCEL UPLOAD (Report + Mock Poll)
end
namespace :pr do resources :records end
namespace :social_media do
  resources :social_pages do resource :meta_connection, only: %i[new create] end
  resources :bulk_posts; resources :influencers
  resources :bulk_messages; resources :contact_groups; resources :ivrs_campaigns
end
namespace :voter_lists do
  resources :voters, only: %i[index show]                # filtered lookup State→…→Booth
  resources :imports, only: %i[new create]               # VOTER ROLL BULK UPLOAD
end
namespace :rag_mapping do resources :entries, only: :index end
```

### Bulk upload / import flows

- **Voter roll (Epic 6 / Story 6.1):** `/voter_lists/imports` → `Imports::VoterRollImporter` (roo/creek, booth_id resolution, PII encryption) → `ImportVoterRollJob` (async, per-row errors).
- **Ground Reports + Mock Poll (Epic 3 / Story 3.5):** `/ground_reports/imports` → `Imports::{GroundReportImporter,MockPollImporter}` → `ImportGroundReportsJob`.
- **Who may upload:** a role with the scoped import capability, or Admin. Imported rows are owned by the importing user/branch, carry the importer's `organization_id`, and surface per-row errors without aborting the file. All imports go through `Imports::BaseImporter` for consistent scoping/error handling.

### Architectural Boundaries

- **Scope boundary (hardest line):** org-side controllers run inside `acts_as_tenant`; the `Console::` namespace does NOT — it is the only place that may cross orgs, always via `Console::BaseController` which logs access and shows the banner.
- **Policy boundary:** no controller touches a model without a Pundit policy scope. The base policy encodes `organization → module-permission → subtree`; module policies specialize it.
- **Service boundary:** all external I/O (Meta/WhatsApp/IVRS/S3) lives behind `app/services` adapters; controllers/models never call providers directly. Jobs wrap services for async.
- **Data boundary:** every domain model includes `OrganizationScoped`; `Voter` additionally under Postgres RLS. Reference data (geography/parties/catalogs) is global, Admin-only.

### Requirements → Structure Mapping

- **Epic 0** → `models/{admin,organization,user,role,...}`, `models/concerns/*`, `policies/application_policy`, `controllers/console/*` (incl. geography + catalogs), `services/tenancy/*`, `views/ui/*`, `test/isolation/*`, `models/voter_lists/voter` (0.15).
- **Epic 1 (KC)** → `kitchen_cabinet/*`, `javascript/controllers/{voter_gate,sentiment_picker}`, `ui/_ticket_card`; `console/ticket_categories` (1.1).
- **Epic 2–4** → `{cadre_program,ground_reports,pr}/*`, `services/imports/*` + `ground_reports/imports` (Epic 3), `console/{pr_categories,media_platforms,outdoor_ad_types}` (Epic 4).
- **Epic 5** → `social_media/*`, `services/{meta,bulk,ivrs}/*`, `jobs/*` (fan-out, daily sync).
- **Epic 6** → `voter_lists/*`, `voter_lists/imports` + `Imports::VoterRollImporter`, RLS migration, export logging.
- **Epic 7** → `rag_mapping/rag_entry`, `services/rollups/*`, `jobs/compute_rag_rollup_job`.
- **Epic 8** → CI isolation gate (`test/isolation`), load-test harness, APM/RLS/encryption verification.

### Integration Points & Data Flow

- **Internal:** request → ApplicationController (set tenant) → Pundit scope → model → view; mutations → audit concern → `ActivityLog`.
- **External:** controller → service adapter (Faraday) → provider; async via job-per-target; results persisted to `*_target`/`*_post` rows; live status pushed via Turbo Stream over Solid Cable.
- **Files:** uploads → Active Storage → S3; served via CloudFront, never through the app.
- **Rollups:** recurring job → `rollups/*` → `RagEntry`/snapshot tables → dashboards read precomputed.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:** All choices interlock cleanly — Rails 8.1 + Hotwire + Propshaft + Tailwind v4 (tailwindcss-rails 4.4) are a verified-compatible set; Devise ×2 + Pundit + acts_as_tenant + closure_tree is a well-trodden Rails authorization stack; Solid Queue/Cache/Cable on separate DBs is a Rails 8 first-class pattern. No contradictory decisions.

**Pattern Consistency:** The "never bare `Model.where` / always policy-scope inside tenant context" rule is consistent with the four-layer isolation decision and the Pundit/acts_as_tenant choices. Namespacing (`Console::` vs org modules) aligns with the two-Devise-scope decision. Minimal-Hotwire posture is consistent with the no-API, server-rendered decision.

**Structure Alignment:** The directory tree, routes, and boundaries realize every decision — the Console namespace isolates operator access, service objects wrap all external I/O, and concerns (OrganizationScoped/SoftDeletable/FullyVersioned) encode the cross-cutting rules once.

### Requirements Coverage Validation ✅

**Epic Coverage:** All 9 epics map to concrete directories/routes (see Requirements → Structure).
**FR Coverage:** FR1–FR54 trace to modules/controllers/models; the shared substrate (FR48–54) lands in Epic 0 concerns + `ui/` partials.
**NFR Coverage:** Isolation (NFR1–5) → four layers + RLS + isolation test gate; scale (NFR6–17) → multi-DB, PgBouncer, replicas, subtree cache, precomputed rollups, Pagy, independent job tier, Datadog, load test; governance (NFR18–20) → AR encryption, discard, encrypted tokens; integrations (NFR21–23) → vendor-agnostic services + idempotent sync; compliance (NFR24–25) → Epic 8.

### Implementation Readiness Validation ✅

**Decision Completeness:** Critical decisions documented with verified versions.
**Structure Completeness:** Complete tree, explicit routes/URLs, import/upload flows, and requirements mapping present.
**Pattern Completeness:** Naming, structure, format, communication, and process patterns defined with the enforcement/anti-pattern list.

### Gap Analysis Results

**Critical (block Epic 0 start):** none.
**Important (block specific later epics, not Epic 0):**
- The **data model** (table/column detail) lives in brief §7 / the addendum; this architecture *references* it rather than duplicating. A consolidated ERD would help — recommended as a follow-up, not a blocker.
- **UX specs exist only for Console + Kitchen Cabinet**; Epics 2–7 need a UX pass before their build.
- **OQ-4** (WhatsApp/IVRS vendors) blocks the actual *send* in Epic 5, not the schema.
- **OQ-7** (what "10k concurrent" means) must be resolved before Epic 8's load test is meaningful.
- The **acts_as_tenant + Postgres RLS** integration (session GUC wiring) needs a concrete migration/recipe during Epic 0 Story 0.2/0.15 — pattern stated, recipe TBD.

**Nice-to-have:** CI/CD pipeline spec, deployment topology diagram, seed-data catalog.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION — all 16 checklist items satisfied and no critical gaps; Epic 0 can start now. The important gaps above affect later epics (UX coverage, vendor/load questions) and are tracked, not blocking.

**Confidence Level:** High for the foundation and Kitchen Cabinet (full PRD + UX + architecture); Medium for Epics 2–7 pending their UX pass.

**Key Strengths:** isolation designed in depth (4 layers + RLS + a release-gating test suite); one rendering/auth/scoping surface (low leak-risk, low complexity); reusable substrate so modules stay thin; versions verified current.

**Areas for Future Enhancement:** consolidated ERD; UX for Epics 2–7; resolve OQ-4/OQ-7; concrete RLS/acts_as_tenant recipe; CI/CD + deployment topology.

### Implementation Handoff

**AI Agent Guidelines:** follow decisions exactly; route every read through a Pundit scope inside tenant context; add an isolation test per new model; keep interactivity to the minimal-Hotwire posture; reuse `ui/` partials; never hard-delete or store PII/tokens in plaintext.

**First Implementation Priority:** Story 0.1 — `rails new .` (Rails 8.1) in place, then the isolation spine (0.2) and two Devise scopes (0.3).
