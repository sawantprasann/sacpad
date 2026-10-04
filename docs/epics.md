---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - docs/prds/prd-sacpad-2026-10-04/prd.md
  - docs/prds/prd-sacpad-2026-10-04/addendum.md
  - docs/ux-designs/ux-sacpad-2026-10-04/DESIGN.md
  - docs/ux-designs/ux-sacpad-2026-10-04/EXPERIENCE.md
architectureSource: "No formal architecture.md — PRD addendum used as the architecture input (user decision 2026-10-04)."
uxScope: "UX spec covers Platform Console + Kitchen Cabinet only; other modules draw stories from PRD FRs, UX-DRs to be added in later UX runs."
---

# SAC-PAD - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for SAC-PAD, decomposing the requirements from the PRD, the UX Design (DESIGN.md + EXPERIENCE.md, scoped to Platform Console + Kitchen Cabinet), and the architecture decisions captured in the PRD addendum into implementable stories.

## Requirements Inventory

### Functional Requirements

**Foundation — Multi-Tenancy, Hierarchical RBAC & Tenant Isolation (PRD §4.1)**
- FR1: Separate `Admin` account type — distinct model/table/login route (`/console`), no `organization_id`/`parent_id`/`role_id`, `tier` of `full`/`ops`; architecturally unreachable from any `User`-scoped query.
- FR2: Organization as tenant boundary — every `User` and domain record has a required, `NOT NULL`, FK-constrained `organization_id`; no "Admin exception" row.
- FR3: Multiple Org Admins per organization — no cap; each has full org-wide RWU + soft-delete, all rooted at the tree top.
- FR4: Unlimited-depth user hierarchy with scoped visibility — self-referential tree; reads scoped to viewer's subtree ∩ organization ∩ module permission; "Get All Details" = "all I may see," paginated; subtree set cached, invalidated on hierarchy change.
- FR5: Data-defined roles with per-module access levels (`none`/`read`/`write`) + `can_create_users`; new roles without deploy; `write` implies read.
- FR6: Role definition is Admin-only (Platform Console); role assignment is by the user's creator from the catalog; no Org-Admin "create role" UI in v1.
- FR7: User creation gated by `can_create_users` (default only `org_admin`); enforced in policy, not just UI; grantable without deploy.
- FR8: Dreamline User full-breadth `write` on every module within its org/subtree for v1; narrowing later is a data change.
- FR9: Organization deactivation cascade — inactive org immediately blocks login + all data visibility at every depth; enforced at auth and in every Pundit scope base query.
- FR10: Tenant isolation is defense-in-depth — per-action policy scope + denormalized `organization_id` + model-layer auto-scope that refuses unscoped queries + DB `NOT NULL`/FK; Admin access is not a bypass flag; inherited-scope child tables only reachable through their tenant-scoped parent.
- FR11: Mandatory cross-tenant isolation test suite — proves A-cannot-reach-B for every module (expect 404, not 403); a missing test is a release blocker.
- FR12: Constituency link determines an org's default geography — one Loksabha or one Assembly per org; modules derive villages/assemblies from it; rivals may share geography.

**Platform Console (PRD §4.2)**
- FR13: Organization lifecycle management — create org (+ constituency, initial party, initial Org Admin), orgs list with health, deactivate/reactivate; `ops` tier sees only assigned orgs.
- FR14: Role & permission catalog editor (Console-only); changes take effect without deploy; system roles protected.
- FR15: Shared reference-data editors — Parties, geography (State/Loksabha/Assembly/Village/Booth), ticket categories, PR categories, media platforms, outdoor-ad types; additions without deploy.
- FR16: Per-organization `Politician` roster management — own candidate (exactly one, partial-unique, name synced to org) + opponents; Admin-managed; soft-deletable.
- FR17: Cross-org audit log view — every Admin view/export of a specific org's data logged (who/org/action/when); queryable.
- FR18: Platform operational health view — sync success rate, queue depth, external rate-limit/token headroom.

**Kitchen Cabinet (PRD §4.3)**
- FR19: Ticket capture under extensible categories (12 seeded + Admin-extensible + "Other"); sidebar category filter; pre-filled new ticket.
- FR20: Ticket status workflow `open`→`in_progress`→`closed`/`blocked`; every transition logged (Tier-2).
- FR21: Voter-ID capture gated on resolution — `voter_id` settable only when status=closed; model-level validation; loose lookup to Voter (not FK).
- FR22: Voter-sentiment capture at closure — closing with voter_id surfaces matched voter(s) and prompts pleased/transit/displeased, written to the Voter.
- FR23: Per-ticket follow-up action log — timestamped, attributed, optional attachment; any KC `write` role; distinct from status-change log.

**Cadre Program (PRD §4.4)**
- FR24: Cadre activity capture across six fixed categories — shared base + per-category detail; shared impact/"media value" note + photos.
- FR25: One-to-One activity references a karyakarta via `User` FK or free-text fallback.
- FR26: Cadre activity feed and rollups keyed off the base record (single query), subtree/org scoped; export.

**Ground Reports (PRD §4.5)**
- FR27: Village report with text/audio/video testimonials (one report → many); all rows `village_id`+`organization_id`.
- FR28: Worship places, single editable yatra note per village (composite uniqueness), history-preserving political position (reuses Party catalog).
- FR29: Local contacts — two non-user kinds (local karyakartas; non-system admin contacts).
- FR30: Mock Poll survey capture (one row per respondent per politician) with read-time win-likelihood tally.
- FR31: Bulk Excel import for Report and Mock Poll by a scoped import role; imported rows respect ownership/scoping.

**PR (PRD §4.6)**
- FR32: PR record capture across six categories — base record + platform (catalog or free-text), URL, sentiment, publish date, thumbnail, attachments.
- FR33: Outdoor-ad counts (per extensible ad type) and podcast recording date (the two detail types).

**Social Media v1 (PRD §4.7)**
- FR34: Karyakarta Pages registry — Meta OAuth connect, encrypted token, FK-with-fallback page owner.
- FR35: Compose-once, publish-to-many `BulkPost` (all / geography-filtered / explicit targets).
- FR36: Asynchronous fan-out with per-target status + individual retry; respects Meta rate limits; live status view.
- FR37: Per-post reporting — organic/paid reach, views, explicit likes + comments counts.
- FR38: Influencers outreach log (manual entry, no API); rolls up via assembly.
- FR39: Bulk WhatsApp/SMS broadcast (two channels, one feature) — geography/contact-group/explicit targeting; per-recipient status; Voter-sourced geography audiences.
- FR40: IVRS voice broadcast with per-recipient call outcome.

**Voter Lists (PRD §4.8)**
- FR41: Filtered voter-list lookup (State→Loksabha→Assembly→Village→Booth), paginated; booth is a real FK.
- FR42: Org-owned voter roll (`Voter` org-scoped, not shared reference).
- FR43: Voter sentiment status (pleased/transit/displeased, mutable); Green/Amber/Red is presentation mapping; history from Tier-1 versioning.
- FR44: PII protection and access control — encryption at rest; deliberate, logged, auditable Voter access stricter than general `write`.

**RAG Mapping (PRD §4.9)**
- FR45: RAG rollup across modules + voter sentiment per geography level (village/booth/assembly/constituency).
- FR46: RAG presentation views — Mapped List, Chart, Dashboard (Bar/Pie/Line, exportable).
- FR47: Precomputed rollups (background job, `computed_at`), not live-aggregated.

**Shared UI/Functional Patterns & Dashboards (PRD §4.10)**
- FR48: Shared module chrome — top bar, module toolbar, left category sidebar, center table/panel, cross-module attachments; all §4.1-scoped.
- FR49: Excel + chart export on every module; subtree/org scoped; Voter exports logged.
- FR50: Single shared Organization Dashboard — widget-composed; each widget scoped + gated by module permission; no role-specific dashboard code.
- FR51: Org-admin-only dashboard widgets (pending items, hierarchy/user-count, recent-deletions) gated by capability, not module permission.

**Audit History & Change Tracking (PRD §4.11)**
- FR52: Tier-1 full version history (Voter PII, User, role-permission, candidate ground-report edits) in per-model version tables; soft-delete tracked as update.
- FR53: Tier-2 lightweight status-transition log (Ticket confirmed); one row per status change.
- FR54: Cross-table activity index — append-only who/what/where, incl. every Admin cross-org access.

**Deferred (v2 / out of scope for v1 — tracked, not built):** Mainline/Fan-Page Media (PRD §4.12), Targets, Info / Village-wise Reports nav, Paid Promotions / Tag Accounts detail, 2FA, Org-Admin custom roles, Dreamline module narrowing.

### NonFunctional Requirements

**Security & Tenant Isolation (PRD §8.1)**
- NFR1: Defense-in-depth isolation across four independent layers (policy scope, denormalized `organization_id`, model-layer auto-scope, DB `NOT NULL`/FK); evaluate Postgres RLS for Voter specifically.
- NFR2: Admin cross-org visibility is a separate, logged code path, never a bypass flag in the shared path.
- NFR3: Mandatory cross-tenant isolation tests are a release blocker (404 not 403), every module.
- NFR4: Credential-stuffing/brute-force resistance — login rate-limiting + account lockout on both scopes; no self-service password reset on `Admin`.
- NFR5: Pre-launch security review / pen test before real voter data, budgeted as its own task.

**Scalability & Performance — 10,000 concurrent users (PRD §8.2)**
- NFR6: Horizontally-scaled, stateless app tier (clustered workers behind LB, autoscaled), sized by load test.
- NFR7: DB connection pooling (PgBouncer, transaction mode) in place before load testing.
- NFR8: Separate databases for jobs / cache / cable from primary OLTP.
- NFR9: Read replica(s) for heavy-read paths (dashboards, exports, Voter lookups).
- NFR10: Cache the subtree lookup; invalidate only on hierarchy change.
- NFR11: Precompute (not live-aggregate) rollup dashboards (RAG, reach).
- NFR12: Paginate every listing (Pagy); Voter lists can be millions of rows.
- NFR13: Deliberate indexing — `organization_id`/`owner_id`, hierarchy/closure columns, composite filter indexes.
- NFR14: CDN in front of stored media; don't serve files through the app.
- NFR15: Background-job workers sized independently of the web tier (sync/bulk-publish fan-out must not starve exports).
- NFR16: Observability day one (APM — Datadog available — + Postgres slow-query logging).
- NFR17: Load test before launch against the realistic usage mix (resolve OQ-7 first).

**Data Governance & Privacy (PRD §8.3)**
- NFR18: Voter PII field-level encryption at rest; deliberate/auditable access; logged exports.
- NFR19: All domain deletes are soft deletes; no hard delete, ever; recoverable + audited.
- NFR20: Stored external tokens encrypted; never exposed to non-Org-Admin roles.

**Integrations & External Dependencies (PRD §8.4)**
- NFR21: Meta Graph daily sync idempotent, per-page-failure-tolerant, alerts on expired/revoked tokens.
- NFR22: Vendor-agnostic WhatsApp/SMS and IVRS integration boundary (vendors TBD, schema stays agnostic).
- NFR23: External rate limits are a first-class operational constraint.

**Compliance & Regulatory (PRD §8.5)**
- NFR24: Legal/compliance review (DPDP, election-communication rules) before launch.
- NFR25: Consent/opt-in for Voter-sourced numbers, WhatsApp template approval, tiered volume limits confirmed before any send ships.

**Operational / Reliability (PRD §8.6)**
- NFR26: Every login records a timestamp + increments a login counter (shown in top bar).
- NFR27: Every create/update timestamped and attributable (see audit tiers).

### Additional Requirements

*From the PRD addendum (used as the architecture input) — brief §2/§7/§8b/§10.*

- **Starter/scaffold (impacts Epic 0, Story 1):** greenfield **Ruby on Rails 8** app with **TailAdmin** (Tailwind admin template) integrated; PostgreSQL. No external starter repo — `rails new` + TailAdmin theme wiring is the scaffold story.
- **Auth:** Devise with **two scopes** — `devise_for :users, path: ''` and `devise_for :admins, path: 'console'`; module sets per brief §2 (no `registerable`; `recoverable` on `User` only; `lockable` both, `:both` vs `:time`). 2FA (`devise-two-factor`) deferred to Phase 2.
- **Authorization:** Pundit policies scoped by role + hierarchy subtree.
- **Hierarchy:** `closure_tree` on `users`; `subtree_ids` cached (Solid Cache/Redis).
- **Tenant isolation:** `acts_as_tenant` model-layer net; denormalized `organization_id`; DB `NOT NULL`+FK; evaluate RLS for `Voter`.
- **Soft delete:** `discard`. **Versioning:** `paper_trail` with **custom per-model version classes** (Tier 1) + lightweight `TicketStatusChange`-style log (Tier 2) + cross-table `ActivityLog`.
- **Jobs/cache/cable:** Solid Queue / Solid Cache / Solid Cable on **separate databases**; recurring via `config/recurring.yml`.
- **Files:** Active Storage (polymorphic `has_many_attached`) + CDN.
- **Charts:** Chartkick + Chart.js (Groupdate for time-series). **Excel:** `caxlsx` (export), `roo`/`creek` (import). **Pagination:** Pagy. **N+1:** Bullet (dev/staging).
- **Scale infra:** PgBouncer (transaction pooling); independent job-worker tier; Datadog APM + Postgres slow-query logging; pre-launch load test.
- **Integrations (Epic 4a owns Meta work):** Meta Graph API over Faraday/HTTParty (Batch API; no wrapper gem); WhatsApp BSP/Cloud API (vendor TBD); IVRS vendor (TBD).
- **Geography & constituency:** `State→Loksabha→Assembly→Village→Booth` reference tables; `Organization` polymorphic `constituency_id/type`; org-scoped village-content tables need composite `(village_id, organization_id)` uniqueness.
- **Suggested epic sequencing (brief §10):** Epic 0 (foundation) → Epic 1 KC → Epic 2 Cadre → Epic 3 Ground Reports → Epic 4 PR → Epic 4a Social Media v1 → Epic 5 Voter Lists → Epic 6 RAG Mapping; cross-cutting infra sequenced early (Epic 0 depends on parts of it).

### UX Design Requirements

*From DESIGN.md + EXPERIENCE.md. Scoped to Platform Console + Kitchen Cabinet (the only areas with UX spec this run); other modules inherit the shared chrome below but need their own UX pass later.*

**Foundational / cross-cutting (both skins)**
- UX-DR1: TailAdmin is the base component system; SAC-PAD ships only the delta — do not re-build table/form/modal/sidebar/card/toast.
- UX-DR2: Shared module chrome component set — top bar (app name, user photo/name, session timestamp, login count, settings), module toolbar (Export Excel · Prepare Chart · Bar/Pie/Line toggle · Export Chart · Get All Details), left category/entity sidebar, center table/panel. Built once, reused by every module.
- UX-DR3: **Per-org party-theming engine** — resolve `Party.color`+logo at login; apply as *accent only* (buttons, active nav, links, FAB, chart lead color, header logo); auto-compute AA-safe foreground; Independent orgs use fallback accent + SAC-PAD mark.
- UX-DR4: **Reserved RAG/sentiment palette** — green=pleased, amber=transit, red=displeased as semantic constants rendered as SOLID `rag-chip`s; no theme/module may repurpose; clamp party greens/reds that collide.
- UX-DR5: **Workflow-status palette distinct from RAG** — `status-pill` (open/in_progress/closed/blocked) as subtle cool tinted pills with a dot, never solid; closed/blocked visually separated from rag-green/red.
- UX-DR6: Tabular-figures (`numeric`) treatment for all columnar numbers (ticket numbers, counts, tallies, login count, send progress).
- UX-DR7: WCAG 2.2 AA both skins/widths; **RAG & status never by color alone** (always a label + dot); locked fields announce their unlock condition; keyboard-reachable; AA focus ring.
- UX-DR8: Pagination only (no infinite scroll); no hover-only affordances on touch; modal stacks ≤ 1 deep; no silent destructive actions.

**Kitchen Cabinet (mobile-first, responsive up)**
- UX-DR9: Mobile three-level drill IA (category list → `ticket-card` list → ticket detail) with a persistent party-accented **`new-ticket-fab`**; desktop = TailAdmin sidebar + center table + detail shell.
- UX-DR10: **`ticket-card`** (mobile) — whole-card tap-through; shows person+village, category icon, `status-pill`, reported date; no swipe actions v1. Desktop row = click-through with per-column filters.
- UX-DR11: **`voter-gate-field`** — always visible; locked (disabled + lock glyph + helper "Voter ID unlocks once this issue is closed") unless status=closed; normal styling, not error styling.
- UX-DR12: **Two-step closure flow** — confirm resolution + closure date → unlock voter_id → **`sentiment-picker`** (3-segment pleased/transit/displeased); closing without a voter allowed; "no voter match" allows close anyway (loose lookup); quiet factual confirmation ("on record as help delivered"), no celebration.
- UX-DR13: **Follow-up log** component — append-only, timestamped, attributed, optional attachment, newest-first; distinct from the status-change history.
- UX-DR14: KC state patterns — skeleton load; empty-category CTA; blocked-ticket prompt to add a follow-up blocker note; 44px touch targets.

**Platform Console (desktop-primary, neutral steel skin)**
- UX-DR15: **Constant steel operator skin** — never themed; distinct `console-bar` chrome so the operator can't mistake it for a campaign.
- UX-DR16: **Persistent `console-org-banner`** whenever an Admin views a specific org's data ("You're viewing {Org}'s data. This access is logged."); non-dismissible for the visit.
- UX-DR17: **Create-org wizard** — linear/resumable; constituency is a one-time hard choice (one Loksabha OR Assembly); provisions ≥1 Org Admin before finishing.
- UX-DR18: **Role editor** — module × access-level (none/read/write) matrix + `can_create_users` toggle; system roles flagged/protected.
- UX-DR19: `ops`-tier out-of-scope orgs are **absent** from lists (not shown-and-locked); permission-denied modules simply don't render (no "access denied" screen); cross-tenant access shows generic "Not found."
- UX-DR20: Reference-data editors and org-health list per Console IA (parties, geography, categories, platforms, ad types; orgs list with active/inactive, user counts, last activity).

**Voice & tone**
- UX-DR21: Calm, specific, person-centred microcopy (English-only v1); plain over cute; an issue belongs to a *person in a village*. (See EXPERIENCE.md Voice and Tone table.)

### FR Coverage Map

- FR1–FR12: **Epic 0** — multi-tenancy, hierarchical RBAC, tenant isolation foundation.
- FR13–FR18: **Epic 0** — Platform Console (org lifecycle, role catalog, reference data, Politician roster, audit log, platform health).
- FR19–FR23: **Epic 1** — Kitchen Cabinet (capture, status workflow, voter-ID gate, sentiment capture, follow-up log).
- FR24–FR26: **Epic 2** — Cadre Program (six-category base+detail, one-to-one karyakarta, feed/rollups).
- FR27–FR31: **Epic 3** — Ground Reports (report+testimonials, worship/yatra/position, local contacts, mock poll, Excel import).
- FR32–FR33: **Epic 4** — PR (base record across categories, outdoor-ad counts + podcast date).
- FR34–FR40: **Epic 5** — Social Media v1 (karyakarta pages, bulk post, async fan-out, per-post reporting, influencers, bulk WhatsApp/SMS, IVRS).
- FR41–FR44: **Epic 6** — Voter Lists (filtered lookup, org-owned roll, sentiment, PII controls). *Note: the `Voter` table + org-scope + sentiment columns are scaffolded in Epic 0 as a shared primitive so Epic 1 (FR22) can write to it; the module experience is Epic 6.*
- FR45–FR47: **Epic 7** — RAG Mapping (cross-module + sentiment rollup, three views, precomputed).
- FR48–FR51: **Epic 0** (frameworks: shared chrome, export, dashboard widget-composition) — individual module widgets + per-module export wired within each module epic.
- FR52–FR54: **Epic 0** (frameworks: Tier-1 version classes, Tier-2 status log, cross-table ActivityLog) — per-model version classes added as each model is built.

*NFR homes:* NFR1–NFR5 (isolation/auth hardening) → Epic 0, verified in Epic 8; NFR6–NFR16 (scale/perf) → Epic 0 scaffolds (multi-DB, pooling, observability, subtree cache) + per-module (pagination, precompute in Epic 7, PII encryption NFR18 in Epic 6, integration idempotency NFR21 in Epic 5), all verified in Epic 8; NFR17/NFR24/NFR25 → Epic 8; NFR19/NFR20/NFR26/NFR27 → Epic 0 (soft-delete, token encryption, login tracking, attribution).

## Epic List

### Epic 0: Secure Multi-Tenant Foundation & Platform Operations
An operator (`Admin`) can scaffold the application, onboard an organization, define roles, and seed shared reference data; an Org Admin can log in and build/manage their user hierarchy — with tenant isolation, audit trails, and the shared TailAdmin UI shell proven from day one. Every later epic builds on this and nothing here requires a future epic. Includes the `Voter` primitive (table + org-scope + sentiment columns) so Epic 1 can write sentiment without depending on Epic 6.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6, FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR48, FR49, FR50, FR51, FR52, FR53, FR54

### Epic 1: Kitchen Cabinet — Grievance Capture to Proof of Help
A field user can log a constituent's grievance under a category, work it through a status workflow with a running follow-up log, and on genuine resolution attach the voter ID (gated until closed) and record voter sentiment — turning a request into permanent, attributable proof of help delivered.
**FRs covered:** FR19, FR20, FR21, FR22, FR23

### Epic 2: Cadre Program — Party-Organizing Activity
A user can record cadre activity across six fixed categories (shared base + per-category detail), reference karyakartas reliably, and surface it in the activity feed and exports.
**FRs covered:** FR24, FR25, FR26

### Epic 3: Ground Reports — Village-Centric Field Intelligence
A user selects a village and works its sub-sections (report + testimonials, worship places, yatra note, political position history, local contacts, mock poll), including external-agency Excel import — with every piece of content org-scoped over shared geography.
**FRs covered:** FR27, FR28, FR29, FR30, FR31

### Epic 4: PR — Traditional Media Monitoring
A user can record media coverage across six categories on a shared base record, with structured outdoor-ad counts and podcast recording dates where needed, plus per-category export.
**FRs covered:** FR32, FR33

### Epic 5: Social Media v1 — Karyakarta Pages, Bulk Outreach & Meta Integration
A user can register karyakarta Facebook/Instagram pages, compose once and publish to many with asynchronous per-target retry and per-post reporting, log influencer outreach manually, and broadcast Bulk WhatsApp/SMS and IVRS by geography or list. This epic owns the Meta Graph API integration.
**FRs covered:** FR34, FR35, FR36, FR37, FR38, FR39, FR40

### Epic 6: Voter Lists — Electoral Roll & PII-Guarded Sentiment
A user can filter and page the org-owned electoral roll down to booth level and manage per-voter sentiment, with PII encryption, logged exports, and a stricter-than-default access grant.
**FRs covered:** FR41, FR42, FR43, FR44

### Epic 7: RAG Mapping — Constituency Risk/Opportunity Rollup
A user can see a red/amber/green rollup across Kitchen Cabinet, Ground Reports, Cadre Program, and voter sentiment at any geography level, via Mapped List / Chart / Dashboard views, computed by a background job.
**FRs covered:** FR45, FR46, FR47

### Epic 8: Scale, Security & Launch Readiness
Before real voter data goes live, the platform is load-tested against the clarified 10k-concurrent usage shape, passes a security/pen-test review, and clears the DPDP/election-communication and consent/opt-in sign-off — verifying the scale and security NFRs designed into the earlier epics.
**FRs covered:** (NFR gate) NFR5, NFR17, NFR24, NFR25; verifies NFR6–NFR16

---

## Epic 0: Secure Multi-Tenant Foundation & Platform Operations

An operator can scaffold the app, onboard an organization, define roles, and seed shared reference data; an Org Admin can log in and build/manage their hierarchy — with tenant isolation, audit, and the shared UI shell proven from day one. Includes the `Voter` primitive so Epic 1 can write sentiment without depending on Epic 6.

### Story 0.1: Scaffold the Rails 8 + TailAdmin application

As a developer,
I want a booting Rails 8 + TailAdmin application wired to PostgreSQL with the multi-database and base layout shell in place,
So that every later story has a consistent, production-shaped foundation to build on.

**Acceptance Criteria:**

**Given** a clean environment
**When** the app is generated and configured
**Then** `rails new .` (Rails 8.1, PostgreSQL, `--css=tailwind --skip-git`) is run **in place in the existing project folder** (no new subfolder, `docs/` preserved) and boots, with TailAdmin's HTML/Tailwind components ported into ERB partials via `tailwindcss-rails` (Tailwind v4) + Propshaft
**And** Solid Queue, Solid Cache, and Solid Cable are configured on **separate databases** from the primary OLTP database (NFR8)
**And** a shared application layout shell (top bar region, left sidebar region, center content region) renders using TailAdmin components (UX-DR1/UX-DR2)
**And** a CI workflow boots the app and runs the (initially empty) test suite green.

### Story 0.1a: Integrate the TailAdmin theme (component library)

As a developer,
I want the actual TailAdmin (https://demo.tailadmin.com/) HTML/Tailwind theme ported into a reusable `ui/` ERB component library,
So that every screen inherits the real TailAdmin look instead of a hand-rolled placeholder shell.

**Acceptance Criteria:**

**Given** the Story 0.1 scaffold (minimal placeholder shell)
**When** the TailAdmin theme is integrated
**Then** the TailAdmin **HTML/Tailwind** build is sourced (TailAdmin ships no Rails build — port the framework-agnostic HTML variant) and its design tokens are expressed in the Tailwind v4 theme layer (FR48, UX-DR1)
**And** the shell (sidebar, top bar, breadcrumb) is replaced with TailAdmin's real components, and core components are ported into `app/views/ui/` partials: data table, form inputs/select, buttons, dropdown, badge, modal, alert, card (UX-DR1/UX-DR2)
**And** the `--org-party-color` accent hook and the reserved RAG/status palette (DESIGN.md) are wired into the theme layer, accent-only, AA-safe
**And** a sample page visually matches the TailAdmin demo, no component is rebuilt from scratch that TailAdmin already provides, and the suite + rubocop stay green.

**Note:** depends on Story 0.1; replaces its placeholder shell. Licensing of the TailAdmin build to be confirmed before sourcing (free/open-source HTML variant vs. Pro).

### Story 0.2: Organization tenant boundary and isolation spine

As a developer,
I want an `Organization` model with the defense-in-depth tenant-isolation spine and an isolation test harness,
So that no later feature can leak one organization's data to another.

**Acceptance Criteria:**

**Given** the app scaffold
**When** the tenant layer is added
**Then** an `organizations` table exists (`active` boolean default true, `current_party_id` nullable, polymorphic `constituency_id`/`constituency_type` nullable) (FR2, FR12)
**And** `acts_as_tenant` auto-scopes ActiveRecord queries to a thread-local current organization and **raises** on an unscoped query rather than returning rows (FR10, NFR1)
**And** a Pundit base policy + application-controller scoping hook are in place, plus a convention that every domain table carries a `NOT NULL`, FK-constrained, denormalized `organization_id` (FR10, NFR1)
**And** a reusable cross-tenant isolation test helper exists that asserts "Org A cannot read/update/delete an Org B record (expect 404, not 403)", runnable per model (FR11, NFR3).

### Story 0.3: Admin account type and Platform Console entry

As a platform operator,
I want a separate `Admin` account that logs in at `/console` into a distinct operator shell,
So that platform operations are architecturally separate from any organization's users.

**Acceptance Criteria:**

**Given** the app scaffold
**When** the Admin scope is added
**Then** a standalone `admins` table exists with a `tier` (`full`/`ops`) and **no** `organization_id`/`parent_id`/`role_id` (FR1)
**And** `devise_for :admins, path: 'console'` provides login at `/console` with `database_authenticatable`, `trackable`, `lockable (:time)` — **no** `registerable`, **no** `recoverable` (FR1, NFR4)
**And** authenticated Admins land in a Platform Console shell using the constant neutral **steel skin**, never party-themed, and the console login is not linked from any org-facing page (UX-DR15)
**And** no `User`-scoped query can ever return an `admins` row (FR1).

### Story 0.4: Shared reference data — geography, parties, and the catalog editor

As a platform operator,
I want to manage global geography and party reference data from the Console,
So that organizations can be tied to constituencies and themed by party.

**Acceptance Criteria:**

**Given** an authenticated `full`-tier Admin
**When** reference data is managed in the Console
**Then** `State → Loksabha → Assembly → Village → Booth` reference tables exist and are editable (FR15)
**And** a `parties` table (name, abbreviation, color, logo via Active Storage) is editable (FR15)
**And** a reusable Console "catalog editor" pattern is established (used later for ticket categories, PR categories, media platforms, outdoor-ad types in their module epics) (FR15)
**And** reference data is global (shared across every organization), editable only by `Admin`.

### Story 0.5: Organization onboarding wizard with constituency link

As a platform operator,
I want a create-organization wizard that sets the org's constituency, initial party, and first Org Admin,
So that a new politician's operation can be stood up end to end.

**Acceptance Criteria:**

**Given** geography and parties exist (Story 0.4)
**When** an Admin runs the create-organization wizard
**Then** the wizard is linear and resumable and sets the org identity, a one-time **constituency** choice (exactly one Loksabha **or** one Assembly), and an initial party affiliation (FR12, FR13, UX-DR17)
**And** the wizard cannot finish without provisioning at least one Org Admin account (FR13, UX-DR17)
**And** an Organizations health list shows active/inactive, user counts, and last activity, filtered to assigned orgs only for an `ops`-tier Admin (FR13, UX-DR19/UX-DR20)
**And** `organization.villages`/`assemblies` derive correctly from the constituency type.

### Story 0.6: Organization deactivation cascade

As a platform operator,
I want deactivating an organization to immediately cut off all its users,
So that an ended campaign's data becomes inaccessible in one action.

**Acceptance Criteria:**

**Given** an active organization
**When** an Admin sets it inactive
**Then** every user under it, at every depth, immediately fails authentication (`active_for_authentication?` also checks `organization.active?`) (FR9)
**And** every Pundit scope's base query filters to active organizations, so a live session sees no data after deactivation (FR9)
**And** reactivating restores access without per-user changes.

### Story 0.7: Organization-facing user accounts and login

As an Org Admin,
I want org users to authenticate at the clean root path,
So that a campaign's people can securely access their organization.

**Acceptance Criteria:**

**Given** an organization exists
**When** the User scope is added
**Then** a `users` table exists (`organization_id` required, `parent_id` nullable, `role_id`, name, email, phone, photo, `active`, `last_login_at`, `login_count`) (FR2)
**And** `devise_for :users, path: ''` provides login with `database_authenticatable`, `recoverable`, `rememberable`, `trackable`, `lockable (:both)` — **no** `registerable` (FR2, NFR4)
**And** on each login the timestamp is recorded and the login counter increments, surfaced in the top bar (NFR26)
**And** a user in a deactivated org cannot authenticate (reuses Story 0.6).

### Story 0.8: Roles and permissions catalog with Console editor

As a platform operator,
I want to define roles as data with per-module access levels,
So that organizations can be given module-scoped roles without a deploy.

**Acceptance Criteria:**

**Given** an authenticated Admin
**When** roles are defined in the Console role editor
**Then** `roles` (name, slug, `is_system`, `can_create_users`) and `role_permissions` (role, module enum, `access_level` none/read/write) tables exist (FR5)
**And** the editor presents a module × access-level matrix plus a `can_create_users` toggle, and system roles are flagged and protected (FR6, FR14, UX-DR18)
**And** `write` implies read; a role with `none` on a module cannot reach that module's data or UI (FR5)
**And** role definition is reachable **only** from the Console; no org-facing create-role UI exists (FR6)
**And** the seeded roles include `org_admin` (full access, `can_create_users: true`) and `dreamline_user` (write on every module, `can_create_users: false`) (FR8).

### Story 0.9: Hierarchical user management with scoped visibility

As an Org Admin,
I want to build a user hierarchy of unlimited depth where each person sees only their own branch,
So that cadre members only access data relevant to them.

**Acceptance Criteria:**

**Given** roles exist (Story 0.8) and an Org Admin is the tree root
**When** users are created and the tree is queried
**Then** `closure_tree` maintains the self-referential `users` tree to unlimited depth; whoever creates a user becomes its parent (FR4)
**And** each user's `subtree_ids` are cached (Solid Cache) and invalidated only when the hierarchy changes (FR4, NFR10)
**And** every authorized read is scoped to viewer subtree ∩ organization ∩ module permission; "Get All Details" returns only permitted rows, paginated (FR4, NFR12)
**And** creating a user is allowed only for a role with `can_create_users` (default `org_admin` only), enforced in policy not just UI, and the creator assigns an existing role (FR7)
**And** an organization may have more than one `org_admin` (FR3)
**And** the per-model isolation test from Story 0.2 passes for `User`.

### Story 0.10: Soft-delete and the two-tier audit framework

As a platform operator,
I want every change tracked and every delete recoverable,
So that the platform has an accountable, auditable history.

**Acceptance Criteria:**

**Given** the domain models
**When** records are changed or deleted
**Then** `discard` provides soft-delete (`discarded_at`/`discarded_by_id`); no domain data is hard-deleted; delete is Org Admin/Admin only and asks for confirmation stating recoverability (FR-soft-delete, NFR19, UX-DR8)
**And** a Tier-1 `paper_trail` pattern using **custom per-model version classes** is established (FR52)
**And** a Tier-2 lightweight status-change log pattern is established (FR53)
**And** a cross-table append-only `ActivityLog` (actor + type, action, record type/id, organization, timestamp) records "who did what, where" (FR54)
**And** every create/update is timestamped and attributable (NFR27).

### Story 0.11: Logged Admin cross-org access with persistent banner

As a platform operator,
I want every time I view an organization's data to be logged and visibly flagged,
So that cross-tenant access by operators is never silent.

**Acceptance Criteria:**

**Given** an authenticated Admin viewing a specific organization's data
**When** the org-detail view is opened
**Then** a persistent, non-dismissible `console-org-banner` shows "You're viewing {Org}'s data. This access is logged." for the whole visit (FR17, UX-DR16)
**And** an `ActivityLog` entry (who, which org, action, when) is written for the access (FR17, NFR2)
**And** the cross-org audit log view in the Console is queryable by actor, organization, and action (FR17)
**And** an `ops`-tier Admin can only open orgs it is assigned to; others are absent from the list, not shown-and-locked (UX-DR19).

### Story 0.12: Per-organization Politician roster

As a platform operator,
I want to manage each organization's own candidate and tracked opponents,
So that downstream modules can reference a named Politician.

**Acceptance Criteria:**

**Given** an organization exists
**When** an Admin manages its roster from the Console
**Then** a `politicians` table (org-scoped: name, nullable `party_id`, `is_own_politician`, photo, soft-delete columns) exists (FR16)
**And** a partial-unique index enforces exactly one `is_own_politician: true` per organization, whose name stays in sync with `Organization.name` via callback (FR16)
**And** the roster is org-scoped (not global) and Admin-managed only (not org-facing) (FR16).

### Story 0.13: Platform operational health view

As a platform operator,
I want a health view of jobs, queues, and external-provider headroom,
So that I can spot a failing sync or an expired token before it becomes an outage.

**Acceptance Criteria:**

**Given** background jobs and external integrations exist
**When** the Console health view is opened
**Then** it surfaces daily sync-job success rate, background-queue depth, and external rate-limit/token headroom (FR18)
**And** it highlights failed/stale sync jobs and expired external tokens (FR18)
**And** an `ops`-tier Admin sees health scoped to assigned orgs (FR18, UX-DR19).

### Story 0.14: Shared chrome, export, and the Organization Dashboard framework

As an org user,
I want a consistent themed shell with a shared toolbar and a permission-aware dashboard,
So that every module feels like one tool and shows only what I'm allowed to see.

**Acceptance Criteria:**

**Given** an authenticated org user
**When** any org-side surface renders
**Then** the shared chrome renders — top bar (app name, user photo/name, session timestamp, login count, settings), module toolbar (Export Excel · Prepare Chart · Bar/Pie/Line · Export Chart · Get All Details), left category sidebar, center table/panel (FR48, UX-DR2)
**And** a party-theming engine resolves the org's `Party.color`+logo and applies them as **accent only** (AA-safe foreground auto-computed; Independent orgs use the fallback) — never full-surface, never on the Console (FR-theming, UX-DR3)
**And** a reusable Excel + chart export mechanism exists, scoped to the viewer's subtree/org (FR49)
**And** the Organization Dashboard is a widget-composition framework: each widget runs through the same scoping and renders only if the viewer's role permits that module; org-admin-only widgets (pending items, hierarchy/user-count, recent-deletions) are gated by capability (FR50, FR51)
**And** reserved RAG colors and workflow-status pills follow the DESIGN.md palette discipline, never by color alone (UX-DR4/UX-DR5/UX-DR7).

### Story 0.15: Voter primitive for cross-module sentiment

As a developer,
I want the org-scoped `Voter` table with sentiment columns and Tier-1 versioning,
So that Kitchen Cabinet (Epic 1) can record voter sentiment without depending on the Voter Lists module (Epic 6).

**Acceptance Criteria:**

**Given** the foundation and audit framework
**When** the Voter primitive is created
**Then** a `voters` table exists, org-scoped (`organization_id` required), carrying PII fields and `sentiment_status` (pleased/transit/displeased, nullable, mutable), `sentiment_updated_by_id`, `sentiment_updated_at` (FR42, FR43)
**And** `Voter` has a Tier-1 `VoterVersion` custom version class so sentiment/PII history is captured (FR52)
**And** PII fields are encrypted at rest via Active Record Encryption (NFR18)
**And** the per-model isolation test from Story 0.2 passes for `Voter`
**And** the Voter Lists *experience* (import, filtered lookup, access controls) is explicitly out of scope here and lands in Epic 6.

---

## Epic 1: Kitchen Cabinet — Grievance Capture to Proof of Help

A field user can log a constituent's grievance, work it through a status workflow with a follow-up log, and on resolution attach the voter ID (gated until closed) and record voter sentiment.

### Story 1.1: Ticket categories catalog and sidebar navigation

As a platform operator,
I want to manage the Kitchen Cabinet ticket categories as shared reference data,
So that every organization sees a consistent, extensible category list without a deploy.

**Acceptance Criteria:**

**Given** the Console catalog-editor pattern (Story 0.4)
**When** categories are seeded and managed
**Then** a `ticket_categories` table (name, slug, active, display_order) is seeded with the 12 categories including "Other" and is Admin-editable (FR19, FR15)
**And** categories render as the Kitchen Cabinet left-sidebar submenu, driving a filter over the center list (FR19, UX-DR2)
**And** adding a category makes it appear with no deploy, org-scoped tickets unaffected.

### Story 1.2: Log a ticket (mobile-first capture)

As a field user with Kitchen Cabinet write access,
I want to log a grievance in a few taps, pre-filled to a category,
So that I can capture an issue with a constituent in front of me.

**Acceptance Criteria:**

**Given** a user on the mobile Kitchen Cabinet surface
**When** they tap the party-accented **new-ticket FAB** from a category
**Then** a `tickets` table record is created (owner, organization, ticket_category, person/represents, village/ward, mobile, description, attachments, reported date, nature, reported value, status defaulting to `open`) (FR19)
**And** the form is pre-filled to the active category and targets are ≥44px (UX-DR9, UX-DR14)
**And** attachments (photos) upload via Active Storage
**And** the record carries `organization_id` and passes the per-model isolation test (FR2, FR11).

### Story 1.3: Browse and open tickets (scoped list + detail)

As a user,
I want to see and open the tickets I'm allowed to see,
So that I can work my branch's grievances.

**Acceptance Criteria:**

**Given** tickets exist in my subtree
**When** I open Kitchen Cabinet
**Then** mobile shows a `ticket-card` list (person+village, category icon, status-pill, reported date); desktop shows the filterable center table with per-column filters (UX-DR10)
**And** the list is scoped to viewer subtree ∩ organization ∩ module permission and is paginated; "Get All Details" never returns the raw table (FR4, NFR12)
**And** tapping a card/row opens the ticket detail with fields, attachments, follow-up log, status control, and the voter-gate field.

### Story 1.4: Ticket status workflow with status-change log

As a user,
I want to move a ticket through its status workflow with each change recorded,
So that the team can see progress and measure resolution time.

**Acceptance Criteria:**

**Given** an open ticket
**When** I change its status
**Then** status transitions `open` → `in_progress` → `closed`/`blocked` are allowed and shown as the cool `status-pill` (UX-DR5)
**And** each transition writes a Tier-2 `TicketStatusChange` row (from, to, actor, timestamp) (FR20, FR53)
**And** time-to-resolution is derivable from the status log and the reported date.

### Story 1.5: Per-ticket follow-up action log

As a user with Kitchen Cabinet write access,
I want to add running follow-up notes to a ticket,
So that there is a record of what was actually done about the issue.

**Acceptance Criteria:**

**Given** a ticket
**When** I add a follow-up entry
**Then** a `TicketFollowUp` row is created (note, created_by, created_at, optional attachment) and entries accumulate newest-first (FR23, UX-DR13)
**And** any role with Kitchen Cabinet `write` can add one — no extra capability needed
**And** the follow-up log is visually distinct from the bare status-change history.

### Story 1.6: Voter-ID capture gated on resolution

As the system,
I want to prevent a voter ID from being attached until a ticket is closed,
So that a voter ID on file always means help was actually delivered.

**Acceptance Criteria:**

**Given** a ticket not yet closed
**When** a user tries to set `voter_id`
**Then** the `voter-gate-field` is shown but locked (disabled + lock glyph + helper "Voter ID unlocks once this issue is closed"), and a model-level validation rejects any persist attempt (FR21, UX-DR11)
**And** once status=closed the field unlocks and `voter_id` can be set/updated (FR21)
**And** `voter_id` is a loose lookup to `Voter.voter_id`, not an enforced FK.

### Story 1.7: Two-step closure with voter-sentiment capture

As a user closing a resolved ticket,
I want to attach the voter and record how they feel,
So that resolution feeds the constituency's voter-sentiment picture.

**Acceptance Criteria:**

**Given** a ticket being closed
**When** I complete the closure flow
**Then** step one confirms resolution + closure date; step two optionally matches a `Voter` (from this org's roll) and shows the 3-segment `sentiment-picker` (UX-DR12)
**And** choosing pleased/transit/displeased writes `sentiment_status` (+ updated_by/at) to the matched `Voter` record created in Story 0.15 (FR22, FR43)
**And** closing without a voter is allowed, and "no voter match" still allows close (loose lookup) (UX-DR12)
**And** a quiet factual confirmation ("on record as help delivered") is shown — no celebratory animation.

### Story 1.8: Kitchen Cabinet dashboard widget and export

As a user,
I want Kitchen Cabinet to surface on the dashboard and export,
So that I can monitor and report on grievances.

**Acceptance Criteria:**

**Given** the dashboard framework (Story 0.14)
**When** Kitchen Cabinet contributes its widget and export
**Then** an "open tickets by status" widget renders only for roles permitted on the module, scoped to subtree (FR50)
**And** the filtered ticket table exports to Excel and its chart (Bar/Pie/Line) exports, scoped to the viewer (FR49)
**And** counts use tabular figures (UX-DR6).

---

## Epic 2: Cadre Program — Party-Organizing Activity

A user can record cadre activity across six fixed categories (shared base + per-category detail) and see it in the feed and exports.

### Story 2.1: Cadre activity base capture

As a user with Cadre Program write access,
I want to log an activity with its common fields and photos,
So that cadre work is captured consistently across categories.

**Acceptance Criteria:**

**Given** a user on Cadre Program
**When** they create an activity
**Then** a `CadreActivity` base row is created (owner, organization, category, `impact_notes` rich text / "media value", photos via Active Storage, soft-delete columns) (FR24)
**And** the category is chosen from the six fixed categories (not an Admin-extensible catalog) (FR24)
**And** the record is subtree/org scoped and passes isolation tests.

### Story 2.2: Per-category detail forms

As a user,
I want each category to capture its own specific fields,
So that genuinely different activity types aren't forced into one shape.

**Acceptance Criteria:**

**Given** a chosen category
**When** the detail form renders
**Then** the matching detail record is created: `CadreActivityProgram` (Program By Party + Personal Program), `CadreActivityLeadershipMeet`, `CadreActivityPartyProgramHosted`, `CadreActivityPersonalActivity`, or `CadreActivityOneToOne` (FR24)
**And** One-To-One references a karyakarta via a `User` FK when available, or a free-text fallback name when not (FR25)
**And** each detail row belongs to its `CadreActivity` via a cheap indexed FK.

### Story 2.3: Cadre activity feed and export

As a user,
I want recent cadre activity in one feed and exportable,
So that I can review and report on organizing work.

**Acceptance Criteria:**

**Given** cadre activities exist
**When** the dashboard/feed and export run
**Then** "recent cadre activity" is a single query over the base table (not a six-way union), subtree/org scoped (FR26)
**And** the feed renders as a dashboard widget gated by module permission (FR50)
**And** the filtered list exports to Excel + chart (FR49).

---

## Epic 3: Ground Reports — Village-Centric Field Intelligence

A user selects a village and works its sub-sections, with all content org-scoped over shared geography, including external-agency Excel import.

### Story 3.1: Village report with testimonials

As a user,
I want to record a village's issues/resolutions and villager testimonials,
So that field intelligence is captured per village.

**Acceptance Criteria:**

**Given** a selected village
**When** I create a report
**Then** a `GroundReport` row (village, organization, owner, issue_text, resolution_text, reported_at) is created and can hold many `GroundReportTestimonial` children (person, content_type text/audio/video, text or media attachment) (FR27)
**And** audio/video testimonials store the file via Active Storage
**And** all rows carry `village_id` + `organization_id` and pass isolation tests.

### Story 3.2: Worship places, yatra note, and political position history

As a user,
I want to maintain a village's worship places, a single yatra note, and its ruling-party history,
So that durable village facts are tracked correctly.

**Acceptance Criteria:**

**Given** a selected village
**When** I edit these sub-sections
**Then** `WorshipPlace` rows (any type, not just temples) can be added (FR28)
**And** `VillageYatra` is exactly one editable note per village per org, enforced by a composite `(village_id, organization_id)` unique index (FR28)
**And** `VillagePoliticalPosition` is history-preserving (party from the Party catalog, representative, title, started/ended) with at most one active row per `(village_id, organization_id)` (FR28).

### Story 3.3: Local contacts (non-system people)

As a user,
I want to record village karyakartas and administrative contacts who aren't system users,
So that local contact info is captured without creating logins.

**Acceptance Criteria:**

**Given** a selected village
**When** I add contacts
**Then** `VillageLocalKaryakarta` (name, phone, notes) and `VillageLocalAdminContact` (name, free-text role_title, phone, notes) rows are created, both keyed by village + organization (FR29)
**And** neither is a `User` row.

### Story 3.4: Mock Poll capture and read-time tally

As a user,
I want to capture village survey responses and see who's likely to win,
So that polling informs strategy without a separate tally table.

**Acceptance Criteria:**

**Given** a selected village
**When** survey responses are recorded
**Then** `MockPollResponse` rows are created one per respondent per politician asked about (politician FK, preference_basis individual/party, vote_intent yes/no/undecided, note) (FR30)
**And** win-likelihood is computed on read by grouping responses by village + politician + vote_intent — no stored tally (FR30).

### Story 3.5: Bulk Excel import for Report and Mock Poll

As an external reporting agency with a scoped import role,
I want to bulk-import survey and report data,
So that large datasets enter the system without manual re-entry.

**Acceptance Criteria:**

**Given** a scoped import role
**When** an Excel file is imported for Report or Mock Poll
**Then** rows are parsed (roo/creek) into the correct records, owned by the importing user/branch and carrying the importer's organization (FR31)
**And** import respects the same subtree/org scoping as hand entry
**And** a malformed file surfaces row-level errors without aborting the whole import.

---

## Epic 4: PR — Traditional Media Monitoring

A user records media coverage across six categories on a shared base record, with the two detail types where needed.

### Story 4.1: PR catalogs (categories, media platforms, ad types)

As a platform operator,
I want PR reference catalogs managed from the Console,
So that PR records use consistent, extensible categorization.

**Acceptance Criteria:**

**Given** the Console catalog-editor pattern (Story 0.4)
**When** PR catalogs are seeded/managed
**Then** `pr_categories` (6 seeded), `media_platforms`, and `outdoor_ad_types` tables exist and are Admin-editable, global across orgs (FR15)
**And** categories drive the PR left-sidebar filter (UX-DR2).

### Story 4.2: PR record capture across categories

As a user with PR write access,
I want to log a media-coverage record under a category,
So that traditional-media mentions are tracked.

**Acceptance Criteria:**

**Given** PR catalogs exist
**When** I create a PR record
**Then** a `PrRecord` base row is created (owner, organization, pr_category, title, description, media_platform FK or free-text fallback, url, sentiment positive/negative, published_on, thumbnail_url, attachments, soft-delete) (FR32)
**And** Electronic/Print use the platform catalog; Local-Print/Local-Electronic/Podcasts use the free-text platform fallback (FR32)
**And** the record is subtree/org scoped and exportable (FR49).

### Story 4.3: Outdoor-ad counts and podcast recording date

As a user,
I want Outdoor and Podcast records to capture their extra fields,
So that the two categories that differ are modeled correctly.

**Acceptance Criteria:**

**Given** a PR record in Outdoor Media or Podcasts/Interviews
**When** I add the category-specific detail
**Then** an Outdoor record can hold several `PrRecordOutdoorAdCount` rows (ad type FK + count), and a new outdoor-ad type is addable with just a name (FR33)
**And** a Podcasts/Interviews record can carry a `PrRecordPodcast` recording date in addition to the base publish date (FR33)
**And** the other four categories need no detail record.

---

## Epic 5: Social Media v1 — Karyakarta Pages, Bulk Outreach & Meta Integration

A user registers karyakarta pages, publishes to many asynchronously with per-post reporting, logs influencers, and broadcasts WhatsApp/SMS and IVRS. Owns the Meta Graph API integration.

### Story 5.1: Karyakarta Pages registry with Meta connect

As a user with Social Media write access,
I want to register a karyakarta's page and connect it to Meta,
So that the app can publish to and report on that page.

**Acceptance Criteria:**

**Given** the Social Media module
**When** a page is registered and connected
**Then** a `SocialPage` row (platform, page_type, url, external_page_id, encrypted access_token, insights_available, karyakarta FK-or-fallback) is created via a Meta "connect this Page" OAuth step (FR34)
**And** the access token is stored encrypted and never exposed to non-Org-Admin roles (FR34, NFR20)
**And** the page owner need not be a system `User` (FK-with-fallback).

### Story 5.2: Compose a bulk post with targeting

As a user,
I want to author a post once and choose who it goes to,
So that I can reach many karyakarta pages in one action.

**Acceptance Criteria:**

**Given** registered pages
**When** I compose a `BulkPost`
**Then** a `BulkPost` row (body, media, optional link, target filter) is created, targeting all pages, a geography/hierarchy-filtered subset, or an explicit multi-select (FR35)
**And** a `BulkPostTarget` row is created per target page (FR35).

### Story 5.3: Asynchronous fan-out with per-target status and retry

As a user,
I want publishing to run in the background with per-page results,
So that one failure doesn't block the rest and I can retry individually.

**Acceptance Criteria:**

**Given** a composed bulk post
**When** I publish
**Then** fan-out runs as one Solid Queue job per target page, respecting Meta per-app/per-page rate limits (FR36, NFR23)
**And** each `BulkPostTarget` tracks pending/success/failed, resulting post ID, and error; a live status view shows "N/M published, P pending, F failed — retry" (FR36)
**And** a failed/expired-token target is individually retryable and does not block others (FR36)
**And** the job tier is sized independently of the web tier (NFR15).

### Story 5.4: Per-post reporting

As a user,
I want each published post's metrics tracked,
So that I can measure reach and engagement per page.

**Acceptance Criteria:**

**Given** a published post
**When** metrics are pulled
**Then** a `SocialPagePost` row tracks organic_reach, paid_reach, views, and explicit likes_count and comments_count per page per post (FR37)
**And** reach, likes, and comments are each independently queryable (FR37).

### Story 5.5: Influencers outreach log

As a user,
I want to track influencers and their post results manually,
So that non-API-connected outreach is still recorded.

**Acceptance Criteria:**

**Given** the Influencers sub-section
**When** I record outreach
**Then** `Influencer` (name, platform, page_url, assembly FK, follower estimate) and `InfluencerPost` (requested_on, post_url, reach, likes, comments, screenshot) rows are created, all manual-entry/nullable, no API pull (FR38)
**And** an influencer rolls up to Loksabha via its assembly for Loksabha-level orgs (FR38).

### Story 5.6: Bulk WhatsApp/SMS broadcast

As a user,
I want to broadcast to many recipients across WhatsApp and SMS in one action,
So that I can reach constituents by geography or list.

**Acceptance Criteria:**

**Given** the Bulk WhatsApp/SMS sub-section
**When** I send a broadcast
**Then** a `BulkMessage` (channel whatsapp/sms, template/body, target_type) and per-recipient `BulkMessageTarget` (status pending/sent/delivered/failed/invalid_number) are created (FR39)
**And** targeting supports geography (resolved from `Voter` via the constituency link), a reusable `ContactGroup`, or an explicit list (FR39)
**And** "groups" means named contact lists, not posting into a WhatsApp Group chat (FR39)
**And** the integration boundary is vendor-agnostic, and consent/opt-in + template approval + volume limits are enforced before send (NFR22, NFR25).

### Story 5.7: IVRS voice broadcast with call tracking

As a user,
I want to voice-broadcast a message and track outcomes,
So that I can reach constituents by phone with measurable results.

**Acceptance Criteria:**

**Given** the IVRS sub-section
**When** I run a campaign
**Then** an `IvrsCampaign` (recorded/TTS message, geography target_filter) and per-recipient `IvrsCallAttempt` (call_status delivered/listened_fully/listened_partial/invalid_number/rejected/no_answer/busy, duration) are created (FR40)
**And** targeting reuses the same geography scoping as Bulk WhatsApp/SMS (FR40)
**And** the IVR vendor is an external dependency behind a vendor-agnostic boundary (NFR22).

---

## Epic 6: Voter Lists — Electoral Roll & PII-Guarded Sentiment

A user can import, filter, and page the org-owned roll down to booth level and manage per-voter sentiment, with PII controls. (The `Voter` table + sentiment columns were created in Story 0.15.)

### Story 6.1: Bulk voter roll import

As an operator or scoped import role,
I want to bulk-import the electoral roll for an organization,
So that the org owns its own copy of the roll.

**Acceptance Criteria:**

**Given** the `Voter` primitive (Story 0.15) and geography (Story 0.4)
**When** a roll file is imported
**Then** rows are parsed (roo/creek) into org-scoped `Voter` records, resolving each to the correct `Booth` FK (FR41, FR42)
**And** import is restricted to a scoped role and PII is encrypted at rest (FR44, NFR18)
**And** geography fields other than `booth_id` may remain flat text per the deferred decision (OQ-11).

### Story 6.2: Filtered, paginated voter lookup

As a user with Voter Lists access,
I want to filter the roll down to a booth and open a paged list,
So that I can find voters efficiently at scale.

**Acceptance Criteria:**

**Given** imported voters
**When** I filter State → Loksabha → Assembly → Village → Booth and open the list
**Then** the center panel shows a paginated list (Pagy); millions of rows never render at once (FR41, NFR12)
**And** results are org-scoped; a rival org's roll is never visible (FR42).

### Story 6.3: PII access control and logged exports

As the system,
I want Voter access and exports to be deliberate and logged,
So that the most sensitive PII is protected and auditable.

**Acceptance Criteria:**

**Given** the Voter Lists module
**When** access and export occur
**Then** access to Voter Lists is a deliberate, auditable permission grant stricter than general module `write` (FR44)
**And** every export containing voter data logs who/when/which filters (FR44, FR49)
**And** PII fields are encrypted at rest; evaluate Postgres RLS as an additional layer (NFR18, NFR1).

### Story 6.4: Voter sentiment view and history

As a user,
I want to view and update a voter's sentiment with full history,
So that the sentiment set at ticket closure stays current.

**Acceptance Criteria:**

**Given** a voter with sentiment set (via Epic 1)
**When** I view/edit the voter
**Then** `sentiment_status` is mutable (pleased↔transit↔displeased) and renders as the reserved RAG mapping with labels, never color-alone (FR43, UX-DR4/UX-DR7)
**And** every change is captured in the Tier-1 `VoterVersion` history (FR43, FR52)
**And** Green/Amber/Red is a presentation mapping, not a stored color.

---

## Epic 7: RAG Mapping — Constituency Risk/Opportunity Rollup

A user sees a red/amber/green rollup across modules and voter sentiment at any geography level.

### Story 7.1: Precomputed RAG rollup job

As the system,
I want RAG rollups computed by a background job,
So that dashboards read fast precomputed data at scale.

**Acceptance Criteria:**

**Given** data across Kitchen Cabinet, Ground Reports, Cadre Program, and voter sentiment
**When** the rollup job runs
**Then** `RagEntry` rows (geography, color_status, count, computed_at) are produced per geography level (village/booth/assembly/constituency), including a pleased/transit/displeased voter-sentiment rollup (FR45, FR47)
**And** dashboards read `RagEntry`, not live aggregates over raw tables (FR47, NFR11)
**And** the rollup is org-scoped.

### Story 7.2: RAG views (Mapped List, Chart, Dashboard)

As a user,
I want to see the RAG rollup in list, chart, and dashboard form,
So that I can read the constituency's risk/opportunity at a glance.

**Acceptance Criteria:**

**Given** precomputed `RagEntry` data
**When** I open RAG Mapping
**Then** Mapped List, Chart, and Dashboard views render from the same rollup, with per-color/per-category counts and Bar/Pie/Line charts (FR46)
**And** "how many votes we got" shows as the count of Green (pleased) voters at the chosen level (FR45)
**And** colors carry labels (never color-alone) and export is available (FR49, UX-DR7).

---

## Epic 8: Scale, Security & Launch Readiness

Before real voter data goes live, the platform is load-tested, pen-tested, and compliance-cleared, verifying the scale/security NFRs built into earlier epics.

### Story 8.1: Scale/performance hardening verification

As the platform team,
I want the scale posture verified and tuned,
So that the system holds up at the target concurrency.

**Acceptance Criteria:**

**Given** the earlier epics' scale scaffolding
**When** the scale posture is audited
**Then** PgBouncer transaction pooling, read replica(s) for heavy-read paths, deliberate indexing (organization_id/owner_id, closure columns, composite filters), CDN for Active Storage, and an independently-sized job tier are all in place and verified (NFR6–NFR15)
**And** APM (Datadog) + Postgres slow-query logging are active and surfacing regressions in staging (NFR16).

### Story 8.2: Load test against the clarified usage shape

As the platform team,
I want a load test against the realistic 10k-concurrent usage mix,
So that the concurrency target is validated, not assumed.

**Acceptance Criteria:**

**Given** OQ-7 (what "10,000 concurrent" means) is resolved with the stakeholder
**When** a load test (k6/Locust) runs against a production-shaped staging environment
**Then** the realistic mix (frequent small field reads/writes + occasional heavy dashboard/export) is simulated and the system meets the agreed latency/throughput targets (NFR17)
**And** bottlenecks found are fixed or documented before launch.

### Story 8.3: Security review and penetration test

As the platform team,
I want a security/pen-test pass before real voter data,
So that tenant isolation and PII handling are independently verified.

**Acceptance Criteria:**

**Given** the full v1 build
**When** a security review / pen test runs
**Then** the mandatory cross-tenant isolation test suite passes for every module (404 not 403) and is a release gate (NFR3, NFR5, FR11)
**And** auth hardening (rate-limiting, lockout, no Admin self-service reset) and PII-at-rest encryption are verified (NFR4, NFR18)
**And** findings are remediated before launch.

### Story 8.4: Compliance and consent sign-off

As the platform team,
I want legal/compliance and consent sign-off,
So that voter-PII handling and political communications are lawful before launch.

**Acceptance Criteria:**

**Given** the bulk-messaging and voter-data features
**When** compliance review runs
**Then** a DPDP / election-communication legal review is completed (NFR24)
**And** consent/opt-in for Voter-sourced numbers, WhatsApp template approval, and tiered volume limits are confirmed before any send ships (NFR25)
**And** sign-off is recorded as a launch gate.
