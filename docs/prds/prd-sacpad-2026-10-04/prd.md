---
title: SAC-PAD — Special Administration Cadre, Political Acceleration & Development
status: draft
created: 2026-10-04
updated: 2026-10-04
---

# PRD: SAC-PAD
*Working title — confirm. Derived verbatim from the brief's expansion of the acronym.*

## 0. Document Purpose

This PRD is for the planning and engineering team taking SAC-PAD from specification to build — the downstream `bmad-create-architecture`, `bmad-create-epics-and-stories`, and `bmad-dev-story` workflows, plus the stakeholder (the politician's operation commissioning the platform). It is derived from `docs/project_brief.md`, a decision-dense technical spec, and reorganizes that spec into capability-first requirements: features grouped, Functional Requirements (FR-N) nested and globally numbered for stable downstream reference, a Glossary that fixes vocabulary, cross-cutting non-functional requirements pulled into their own section, assumptions tagged inline and indexed in §10, and the brief's still-open items carried as numbered Open Questions in §9. Implementation-level detail (table shapes, gem choices, column lists) lives in the brief and in `addendum.md` alongside this file — this PRD states *what* the system must do and *why*, not *how* to build it. Where the brief already made a hard architectural decision that is load-bearing for requirements (e.g. `Admin` as a separate account type, tenant isolation as defense-in-depth), the decision is stated here as a constraint and the mechanism is left to the architecture doc.

## 1. Vision

SAC-PAD is a political cadre and constituency-management platform for a single politician's operation. It gives a campaign one place to capture and act on the work that actually wins constituencies: civic grievances brought to the politician (Kitchen Cabinet), party-organizing activity by the cadre (Cadre Program), village-level field intelligence and surveys (Ground Reports), traditional-media coverage (PR), social-media operations at karyakarta scale (Social Media), the electoral roll with per-voter sentiment (Voter Lists), and a red/amber/green rollup of risk and opportunity across the constituency (RAG Mapping) — all surfaced through dashboards and exportable reports.

The platform's defining structural idea is a **hierarchical chain of trust inside one organization**: an Org Admin (the politician and chief of staff) sits at the root, places state-, district-, taluka-, and karyakarta-level users beneath them to any depth, and each person sees only their own branch of the tree. Above every organization sits a platform operator (`Admin`, the development/operations team) that can host **rival politicians from competing parties as separate organizations on the same platform without either ever seeing the other's data**. This is what makes SAC-PAD a product rather than a bespoke campaign tool — and it is also why tenant isolation is the highest-stakes requirement in the system, not a feature.

Because the data is grassroots issue reports, cadre movements, and voter PII — for rival parties, side by side — a cross-tenant leak is not an ordinary bug; it is a product-ending failure and potentially a legal one. SAC-PAD's value proposition therefore rests equally on two things: the constituency-management capability above, and a credible, defense-in-depth guarantee that one politician's operation can never see another's.

## 2. Target User

### 2.1 Jobs To Be Done

- **As the politician / Org Admin**, I want a single rolled-up view of every issue, activity, media mention, and voter-sentiment signal across my whole organization, so I can see where my constituency is strong, at risk, or winnable — and prove to constituents that help was actually delivered.
- **As a field karyakarta or branch head (`User`)**, I want to log the issue in front of me, the activity I just ran, or the village report I just gathered, in seconds, from the field — and see only my own branch's data, uncluttered by the rest of the organization.
- **As a Dreamline User (external vendor)**, I want write access to the modules I support so I can contribute content and data without being a cadre insider.
- **As the platform operator (`Admin`)**, I want to onboard a new politician's organization, define the roles available to it, manage shared reference data (geography, parties, categories), and operate the platform across every tenant — while every cross-organization access I perform is logged.
- **As a reporting/survey agency**, I want to bulk-import village survey and ground-report data into a specific organization's scope without a general-purpose login into its cadre data.

### 2.2 Non-Users (v1)

- **The general public / constituents** — SAC-PAD has no self-service sign-up on either scope (`:registerable` excluded); constituents are *subjects* of records (voters, ticket-reporters), never account holders.
- **Party organizations as entities** — the platform targets individual politicians, not parties; a party is reference data, not a tenant.
- **Opponent politicians as users** — opponents are tracked *about* (the `Politician` roster, Mock Poll, Opposition Pages in v2), never given logins.

### 2.3 Key User Journeys

- **UJ-1. Rohan, a taluka karyakarta, logs a grievance and later closes the loop.**
  - **Persona + context:** Rohan runs a taluka-level desk under a district head; a farmer walks in about a blocked irrigation subsidy.
  - **Entry state:** authenticated as a `User` with `write` on Kitchen Cabinet; lands on the Org Dashboard, opens Kitchen Cabinet, picks the "Farmers" category.
  - **Path:** creates a `Ticket` pre-filled to Farmers → fills person/village/mobile/description, attaches a photo of the paperwork → status `open`. Over the next weeks he adds `TicketFollowUp` notes as the team works it. When the subsidy clears, he sets status `closed`.
  - **Climax:** on closing, the system now lets him attach the farmer's `voter_id` (blocked until this moment) and asks him to mark the voter's sentiment `pleased`. The ticket is now permanent, attributable proof of help delivered.
  - **Resolution:** the farmer shows up as a Green voter in that village's RAG rollup; the politician can reference "we fixed your subsidy" on a future visit.
  - **Edge case:** Rohan tries to set a `voter_id` while the ticket is still `in_progress` — the system refuses (model-level validation, not just a hidden field), because a voter-ID on file means help *delivered*, not requested.

- **UJ-2. Meera, the Org Admin, reads her constituency at a glance before a rally.**
  - **Persona + context:** Meera is the politician's chief of staff with full org-wide access.
  - **Entry state:** authenticated as `org_admin`; lands on the one shared Organization Dashboard, which renders every widget her role can see plus a few org-admin-only widgets.
  - **Path:** scans open tickets by status, the RAG summary for the villages on tomorrow's route, the recent ground-reports feed, and the voter-sentiment rollup → drills into one amber village → sees the unresolved Water tickets dragging it.
  - **Climax:** she exports that village's ticket table to Excel and the RAG chart as an image for the morning briefing.
  - **Resolution:** the rally plan is reprioritized around the amber village. She never sees — and cannot see — the rival politician's organization on the same platform.

- **UJ-3. Dev, on the platform operations team, onboards a new (rival) politician.**
  - **Persona + context:** Dev is a `full`-tier `Admin` — not a `User`, not part of any organization.
  - **Entry state:** authenticated through the separate, non-advertised `/console` route into the Platform Console (never the Org Dashboard).
  - **Path:** creates a new `Organization`, assigns it to a `constituency` (one Assembly or one Loksabha seat), sets its initial `party_membership`, creates its first `org_admin` account, seeds the organization's `Politician` roster (own candidate + known opponents), and confirms which roles from the global catalog apply.
  - **Climax:** the new organization goes live, fully isolated; its Org Admin logs in at the clean root path and sees an empty, scoped dashboard.
  - **Resolution:** two rival candidates in the *same* Assembly now operate on SAC-PAD simultaneously, each referencing the same shared `Village`/`Assembly` reference rows, with every piece of their own content separated by `organization_id`. Every time Dev later views that org's data, an `ActivityLog` entry records who/what/when.

- **UJ-4. A reporting agency bulk-imports a village survey.**
  - **Persona + context:** an external survey vendor with a scoped import permission into one organization.
  - **Entry state:** authenticated as a `User` carrying an import-capable role, scoped to its branch.
  - **Path:** selects a Village in Ground Reports → Mock Poll → uploads an Excel of raw respondent rows → the system parses each respondent-per-politician row into `MockPollResponse` records owned by the importing branch.
  - **Climax:** "who's likely to win" for that village is computed on read from the imported responses; no manual re-entry.
  - **Resolution:** the imported rows respect ownership/scoping like any hand-entered record; a rival org importing the same real village's survey gets entirely separate rows.

- **UJ-5. A social-media coordinator fires one post to hundreds of karyakarta pages.**
  - **Persona + context:** coordinator with `write` on Social Media, managing the Karyakarta Pages registry.
  - **Entry state:** authenticated; the registry holds hundreds of `SocialPage` rows, each with (ideally) a valid connected Meta token.
  - **Path:** composes a `BulkPost` once (text + image) → targets "all karyakarta pages in this district" via the geography filter → clicks publish.
  - **Climax:** one click kicks off asynchronous fan-out — one background job per page — and a live status view fills in ("142/150 published, 6 pending, 2 failed — retry"). Each page's result is tracked independently so one expired token doesn't block the rest.
  - **Resolution:** per-post reach/likes/comments accrue per page over the following day; failed targets are retried individually.

## 3. Glossary

Downstream workflows and readers must use these terms exactly. FRs, UJs, and SMs use Glossary terms verbatim.

- **Admin** — the platform-operator account type (the development/operations team). A genuinely separate account/model from `User` (own login route `/console`, own table, no `organization_id`/`parent_id`/`role_id`). Can operate across every organization (or a scoped subset, for `ops` tier). The *only* account type that can define roles and manage platform-wide shared reference data. "Admin" unqualified always means this account type. Cardinality: a handful of rows platform-wide.
- **Admin tier** — `full` (unrestricted, platform-wide) or `ops` (scoped to specific organizations via an `Admin`↔`Organization` assignment). One `ops` Admin may be assigned to several organizations.
- **Organization** — one row per politician/campaign; the tenant boundary. Carries `active`, a current party pointer, and a `constituency` link. Every `User` and every domain record belongs to exactly one Organization. (Name confirmed to stay "Organization," not "Client.")
- **Org Admin (`org_admin`)** — the full-access org-level role within `User`, rooted at the top of an organization's hierarchy (typically the politician + chief of staff). An organization may have **more than one** Org Admin. Full read/write/update + soft-delete within its own organization only.
- **User** — a person in one organization's cadre hierarchy, holding exactly one role, sitting at one node of the self-referential tree (`parent_id`). Sees data for its own subtree, within its own organization. Not the same thing as `Admin`.
- **Dreamline User** — an external/vendor role within `User` (renamed from an earlier `ad_agency`). For v1, has `write` across **every** module within its organization and subtree (module-level narrowing deferred).
- **Role** — a named, data-defined set of per-module access levels (`none`/`read`/`write`) plus a `can_create_users` capability. Defined only by `Admin`; assigned by whoever creates a user. Global/shared across organizations in v1. Not applicable to `Admin`.
- **Module** — a top-level feature area and the unit of permission granting: Kitchen Cabinet, Cadre Program, Ground Reports, PR, Mainline/Fan-Page Media (v2), Social Media, Voter Lists, RAG Mapping.
- **Hierarchy / subtree** — the self-referential tree of `User`s within one organization, to unlimited depth. A user's **subtree** is itself plus all descendants; the set of record-owner IDs a user may see.
- **Tenant isolation** — the guarantee that one Organization's users can never read/write another's data, enforced in depth (Pundit scope + denormalized `organization_id` + model-layer auto-scoping + DB constraints).
- **Platform Console** — the separate `Admin`-only section of the app (organizations, role catalog, shared reference-data editors, cross-org audit log, platform health). Reached only via the `Admin` login; never linked from the Org Dashboard.
- **Organization Dashboard** — the single shared, widget-composed dashboard used by every `User`-side role; widgets render per the viewer's module permissions and are scoped by subtree.
- **Party** — global reference data (name, abbreviation, color, logo); which party a politician belongs to over time is tracked history-preservingly per organization.
- **Politician** — an **org-scoped** roster entry: the organization's own candidate (exactly one flagged as own) plus tracked opponents. Admin-managed. Distinct from `User` and from `Party`.
- **Geography reference data** — the shared, global, Admin-managed hierarchy `State → Loksabha → Assembly → Village → Booth`. Reference-only: org-specific content about a geography lives in org-scoped tables keyed by both the geography and `organization_id`.
- **Constituency** — the single Loksabha *or* Assembly seat an Organization contests, set once at onboarding; determines which villages/assemblies that org's modules show by default.
- **Ticket** — a Kitchen Cabinet grievance record; carries a status workflow and a resolution-gated `voter_id`.
- **Voter** — an **org-scoped** electoral-roll record (each organization imports and owns its own copy), carrying PII and a mutable sentiment status.
- **Voter sentiment** — `pleased` / `displeased` / `transit` on a Voter, set at ticket resolution; maps presentationally to Green / Amber / Red.
- **RAG** — Red/Amber/Green risk/opportunity rollup across modules and voter sentiment, per geography level.
- **Soft delete** — all domain deletes set `discarded_at`/`discarded_by_id`; no domain data is ever hard-deleted. Org Admin / Admin only.
- **Reference data vs. domain data** — reference data (geography, parties, categories, media platforms, outdoor-ad types) is global and Admin-managed and shared across tenants; domain data is org-scoped and owned by a user.

## 4. Features

Features are grouped roughly by the brief's epic breakdown. FRs are numbered globally (FR-1…FR-N). Module-permission checks, subtree scoping, soft-delete, audit, and export are cross-cutting: they are specified once in §4.1/§4.10/§4.11 and referenced (not repeated) inside each module.

### 4.1 Foundation: Multi-Tenancy, Hierarchical RBAC & Tenant Isolation

**Description:** The central, cross-cutting design requirement. Two nested scoping layers apply to every authorized request: **organization** (which politician's data?) and **hierarchy subtree** (which branch owns the record?). A third, module-permission layer (§3.3) gates *which* modules a role touches at all. `Admin` is modeled as a separate account type outside this entire machinery (§4.2). Realizes UJ-2, UJ-3. This feature is the foundation every other module depends on, and the highest-stakes failure mode in the system (§8.1).

**Functional Requirements:**

#### FR-1: Separate `Admin` account type

An `Admin` authenticates through a dedicated, non-advertised route (`/console`) into the Platform Console, never the Organization Dashboard. `Admin` is a distinct model/table with no `organization_id`, `parent_id`, or `role_id`, and does not participate in the `roles`/`role_permissions` system.

**Consequences (testable):**
- An org-scoped query against users can never return an `Admin` row (architecturally, not by a nil-check) — verified by a test that no `Admin` is reachable through any `User`-scoped query path.
- The `Admin` login route is not linked anywhere in the organization-facing UI.
- `Admin` has a `tier` of `full` or `ops`; an `ops` Admin is scoped to specific organizations via an assignment join.

#### FR-2: Organization as tenant boundary

Every `User` and every domain record belongs to exactly one Organization via a required `organization_id`. There is no "Admin exception" row to carve out, because `Admin` is not a `User`.

**Consequences (testable):**
- `organization_id` is `NOT NULL` with a foreign key on every domain table.
- A newly created domain record inherits `organization_id` from its owner; it cannot be persisted without one.

#### FR-3: Multiple Org Admins per organization

An organization supports more than one `org_admin` from day one (e.g. politician + chief of staff), each with identical full org-wide read/write/update + soft-delete access, all rooted at the top of the tree.

**Consequences (testable):**
- No uniqueness constraint caps `org_admin` count per organization.
- Any `org_admin` can create/modify/soft-delete any record in its organization.

#### FR-4: Unlimited-depth user hierarchy with scoped visibility

`User`s form a self-referential tree of unlimited depth (`parent_id`, nil for an `org_admin` root). Whoever creates a user becomes its parent. Every authorized read is scoped to the viewer's subtree (self + descendants), intersected with organization and module permission.

**Consequences (testable):**
- A user sees records owned by itself or any descendant, and none owned by a peer or ancestor outside its subtree.
- "Get All Details" and every listing resolve to "all records I am allowed to see," never the raw table.
- Subtree membership is efficient at scale (closure-table-backed; see §8.2) and each user's subtree-id set is cached and invalidated only on hierarchy change.

#### FR-5: Data-defined roles with per-module access levels

Roles are data, not a hardcoded enum. A role carries a name, a set of per-module access levels (`none`/`read`/`write`), and a `can_create_users` capability. New module-scoped roles can be added without a deploy. [ASSUMPTION: The eight modules enumerated in the Glossary are the complete v1 permission surface; Mainline/Fan-Page Media remains in the enum though its UI is deferred to v2.]

**Consequences (testable):**
- Adding a role and its grants requires no code change or deploy.
- A role with `none` on a module cannot reach that module's data or UI (including dashboard widgets, §4.10).
- `write` implies read; `read` excludes create/update/delete.

#### FR-6: Role definition is Admin-only; role assignment is by the user's creator

Only an `Admin` may define a role's name, module grants, and `can_create_users` flag (from the Platform Console). Whoever creates a `User` picks an existing role for them from the catalog. No Org-Admin-facing "create a role" UI ships in v1.

**Consequences (testable):**
- No `User`-side role can create or edit a role.
- Role creation is reachable only from the Platform Console.

#### FR-7: User creation is a capability, not a default right

Creating `User` records is gated by the `can_create_users` capability on the creator's role. By default only `org_admin` has it; `Admin` can grant it to another role without a code change. `User` and `Dreamline User` cannot create users by default.

**Consequences (testable):**
- A role without `can_create_users` is refused the create-user action in policy, not just hidden in UI.
- Flipping `can_create_users` on a role grants the action with no deploy.
- [ASSUMPTION: for v1 the effective rule is "only `org_admin` creates users"; whether `can_create_users` persists as a dormant mechanism or is hardcoded is Open Question OQ-8.]

#### FR-8: Dreamline User full-breadth access (v1)

`Dreamline User` has `write` on every module within its organization and subtree for v1, identical breadth to `user`. Narrowing it to PR/Media-only is a later-phase data change (editing role_permissions), not code.

**Consequences (testable):**
- A `Dreamline User` can write to every module its subtree covers.
- Restricting it later requires only editing permission rows.

#### FR-9: Organization deactivation cascade

Setting an organization inactive immediately blocks login and all data visibility for every user under it, at every depth, with no per-user action.

**Consequences (testable):**
- A `User` in a deactivated organization fails authentication (checked at login).
- A live session in a deactivated organization sees no data (every scope's base query filters to active organizations as defense-in-depth).
- The same mechanism can later deactivate a single branch without being a v1 requirement.

#### FR-10: Tenant isolation is defense-in-depth

No single missed scope clause may cause a cross-tenant leak. Isolation rests on independent layers: per-action policy scoping, a denormalized `organization_id` on every domain table, a model-layer auto-scoping safety net that *refuses* to answer an unscoped query, and DB-level `NOT NULL` + FK constraints. `Admin` cross-org access does not run through the `User`-scoped machinery at all (so it is not a bypass flag), and is logged.

**Consequences (testable):**
- A controller action that forgets to apply a policy scope still cannot return another organization's rows.
- A query that runs with no tenant set raises rather than returning unscoped data.
- "Inherited scope" child tables (per-recipient/per-target/snapshot rows) are only reachable through their tenant-scoped parent, never queried standalone by ID.

#### FR-11: Mandatory cross-tenant isolation test suite

The test suite includes an explicit, non-optional category proving cross-tenant access fails for every module: a `User` in Organization A cannot read/update/delete any record of Organization B, returning a 404 (not a 403 that would confirm the record exists).

**Consequences (testable):**
- Isolation tests exist for every module, not spot checks.
- A missing isolation test is treated as a release blocker, equivalent to a missing test for a payment bug.

#### FR-12: Constituency link determines an organization's default geography

Each Organization is tied to exactly one constituency — one Loksabha *or* one Assembly seat — set once by `Admin` at onboarding. Modules that need "which villages/assemblies does this org operate in" derive them from this link (an Assembly-level org sees that assembly and its villages; a Loksabha-level org sees every assembly under it and all their villages).

**Consequences (testable):**
- The constituency type alone determines which geography a module's pickers/filters default to.
- Multiple organizations (rivals) may share the same constituency geography; there is no exclusivity lock on a geography row.
- Changing a constituency is a direct Admin edit (not history-preserving); see OQ-11-adjacent note.

**Feature-specific NFRs:** see §8.1 (Security & Tenant Isolation) and §8.2 (Scalability) — both are load-bearing for this feature specifically and treated as cross-cutting.

### 4.2 Platform Console (Admin)

**Description:** A genuinely separate section of the app for `Admin` only, because operating the platform across every organization is categorically different from running one campaign. It is not "the Org Dashboard with more data." Realizes UJ-3.

**Functional Requirements:**

#### FR-13: Organization lifecycle management

An `Admin` can create an organization, set its constituency (FR-12) and initial party affiliation, create its initial `org_admin` account(s), view an organizations list with health (active/inactive, user counts, last activity), and deactivate/reactivate an organization (triggering FR-9).

**Consequences (testable):**
- Creating an organization also provisions at least one `org_admin`.
- An `ops`-tier Admin sees only its assigned organizations in every Console view, list, and export.

#### FR-14: Role & permission catalog editor

An `Admin` can create/edit roles, their per-module access levels, and the `can_create_users` flag, from the Console (the only place role definition exists).

**Consequences (testable):**
- Changes take effect without a deploy.
- System/seeded roles are editable only per the seeding policy. [ASSUMPTION: system roles are marked and protected from accidental deletion; exact edit rules TBD.]

#### FR-15: Shared reference-data editors

An `Admin` manages all global reference catalogs from the Console: Parties, geography (`State`/`Loksabha`/`Assembly`/`Village`/`Booth`), Kitchen Cabinet ticket categories, PR categories, media platforms, and outdoor-ad types. Each organization's `Politician` roster is Admin-managed too, though it is org-scoped rather than global.

**Consequences (testable):**
- Adding a reference row (e.g. a new ticket category or outdoor-ad type) requires no deploy and is immediately available to every organization.
- Reference data is never org-scoped except the `Politician` roster, which is per-organization.

#### FR-16: Per-organization `Politician` roster management

At onboarding and ongoing, an `Admin` adds/edits/retires (soft-delete) the organization's own candidate and tracked opponents. Exactly one roster entry per organization is flagged as the own candidate, kept in sync with the organization's name.

**Consequences (testable):**
- A partial-unique constraint enforces at most one own-candidate per organization.
- The own-candidate's name stays consistent with the organization name (no silent drift).
- This is not an Org-Admin-facing feature in v1.

#### FR-17: Cross-org audit log view

An `Admin` can view the cross-organization audit log (§4.11), including every `Admin` cross-org data access.

**Consequences (testable):**
- Every `Admin` view/export of a specific organization's data writes an audit entry (who, which org, action, when).
- The log is queryable by actor, organization, and action.

#### FR-18: Platform operational health view

An `Admin` can see platform operational health: daily sync-job success rate, background-queue depth, and API rate-limit headroom with external providers (Meta/WhatsApp/IVRS).

**Consequences (testable):**
- The view surfaces failed/stale sync jobs and expired external tokens.

**Notes:** `[NOTE FOR PM]` whether `ops`-tier Admin gets full admin-equivalent access (including delete) within assigned organizations or something more limited (e.g. read-only) is **OQ-6**.

### 4.3 Kitchen Cabinet

**Description:** Tracks local civic issues/grievances. A person brings an issue, a `User` logs a `Ticket` under one of the Admin-managed categories, the org works it via a running follow-up log, and on genuine resolution the record becomes permanent, attributable proof of help delivered — and the join key to the voter roll. Realizes UJ-1. Uses the standard module toolbar and sidebar-category navigation (§4.10) and subtree scoping (§4.1).

**Functional Requirements:**

#### FR-19: Ticket capture under extensible categories

A `User` with `write` on Kitchen Cabinet can create a `Ticket` pre-filled to a sidebar category (12 seeded, Admin-extensible, incl. an "Other" catch-all), capturing person/represents, village/ward, mobile, a free-text description, attachments, reported date, nature of issue, reported value, and status. Realizes UJ-1.

**Consequences (testable):**
- Categories render as sidebar submenu items driven by reference data, not a hardcoded enum; a new category appears with no deploy.
- Clicking a category filters the center table to that category's tickets, still subtree/org scoped.

#### FR-20: Ticket status workflow

A `Ticket` moves through `open` → `in_progress` → `closed` / `blocked`. Each transition is logged as a lightweight status-change entry (§4.11, Tier 2).

**Consequences (testable):**
- Every status change records from-status, to-status, actor, timestamp.
- Time-to-resolution is derivable from the status-change log and the reported date.

#### FR-21: Voter-ID capture gated on resolution (key business rule)

A `Ticket`'s `voter_id` can be set or updated **only** once its status is `closed`, enforced as a model-level validation (not a UI hint). The `voter_id` is the loose lookup key linking a resolved ticket to the Voter module (not an enforced FK).

**Consequences (testable):**
- Persisting a `voter_id` on an `open`/`in_progress`/`blocked` ticket fails validation.
- A resolved ticket with a `voter_id` is queryable as proof of help delivered in a village.

#### FR-22: Voter-sentiment capture at closure

When a `User` closes a ticket and sets its `voter_id`, the same step surfaces the matched voter(s) and asks the resolver to set sentiment (`pleased`/`displeased`/`transit`), written straight to the Voter row (§4.8). Realizes UJ-1.

**Consequences (testable):**
- Closing-with-voter-id prompts for sentiment in the same flow.
- The chosen sentiment updates the Voter record and feeds RAG (§4.9).

#### FR-23: Per-ticket follow-up action log

Any role with `write` on Kitchen Cabinet can add timestamped free-text follow-up entries (with optional attachment) to a ticket, accumulating the "what did we do about this" report. This is distinct from the bare status-change log.

**Consequences (testable):**
- Multiple follow-up entries accumulate per ticket, each attributed and timestamped.
- No new capability beyond module `write` is required.

### 4.4 Cadre Program

**Description:** Tracks party-organizing activity across six fixed categories whose fields genuinely differ. Modeled as a shared base record plus per-category detail, so scoping/soft-delete/audit/feed logic is written once. The category list is fixed (not Admin-extensible), unlike Kitchen Cabinet. Uses standard toolbar/scoping.

**Functional Requirements:**

#### FR-24: Cadre activity capture across six categories

A `User` with `write` on Cadre Program can log an activity in one of six fixed categories (Program By Party, Leadership Meets, Party Programs Hosted, Personal Program, Personal Activities, One To One), capturing the fields specific to that category plus a shared rich-text impact/"media value" note and photos.

**Consequences (testable):**
- Each category presents its own field set; the shared base carries owner, organization, category, impact notes, and photos.
- A new category is understood to require a new detail shape (not a config change) — this is an accepted non-goal of dynamic extensibility.

#### FR-25: One-to-One activity references a karyakarta

A One-To-One activity references a karyakarta either as a real `User` FK (for reliable per-karyakarta rollups) or, when that person isn't a system user, as a free-text fallback name.

**Consequences (testable):**
- "How many one-to-ones has this karyakarta logged" is reliable at scale when the FK is set.
- A non-user karyakarta can still be recorded via the fallback.

#### FR-26: Cadre activity feed and rollups

The shared base record feeds the Organization Dashboard's cadre-activity feed and Excel export; per-category detail is joined on read.

**Consequences (testable):**
- "Recent cadre activity" is one query over the base table, not a six-way union.
- Export and feed key off the base record, scoped by subtree/org.

### 4.5 Ground Reports

**Description:** Village-centric, not record-centric: a `User` selects a Village first, then works sub-sections about that village — Report, Mock Poll, Worship Places, Yatra, Political Position, Local Contacts. The village is shared reference data; every piece of content about it is fully org-scoped, so rival orgs tracking the same real village keep entirely separate rows. Realizes UJ-4. Supports external reporting-agency bulk import (FR-31, FR-33).

**Functional Requirements:**

#### FR-27: Village report with testimonials

A `User` can record issues found in a selected village and their resolutions, and attach villager testimonials in text, audio, or video form.

**Consequences (testable):**
- One report can carry many testimonials; audio/video is stored as an attachment.
- All rows carry `village_id` + `organization_id`.

#### FR-28: Worship places, yatra note, political position

A `User` can record a village's worship places (any type, not just temples), maintain a single editable yatra note per village (not a dated event log), and track the locally-ruling party/representative history-preservingly (reusing the Party catalog).

**Consequences (testable):**
- Yatra is exactly one editable row per village per organization (composite `(village_id, organization_id)` uniqueness).
- Political Position keeps history (started/ended), with at most one currently-active row per village per organization.

#### FR-29: Local contacts (two kinds, non-users)

A `User` can record two kinds of village people who are **not** system users: local karyakartas (contact info) and non-system administrative contacts (Sarpanch, Gram Sevak, Police, CO, etc., with a free-text role title).

**Consequences (testable):**
- Neither kind is a `User` row; both are standalone contact records keyed by village + organization.

#### FR-30: Mock Poll survey capture and read-time tally

A `User` (or reporting agency) can record village survey responses — one row per respondent per politician asked about — capturing preference basis (individual vs. party), vote intent (yes/no/undecided), and notes. "Who's likely to win" is computed on read by grouping responses; no separate tally table in v1. Realizes UJ-4.

**Consequences (testable):**
- One respondent surveyed about N politicians yields N response rows.
- Win-likelihood is a read-time group-by; no stored tally.

#### FR-31: Bulk Excel import for Report and Mock Poll

An external reporting agency (scoped import role) can bulk-import Report and Mock Poll data via Excel; imported rows respect ownership/scoping (owned by the importing user or their designated village/branch). Realizes UJ-4.

**Consequences (testable):**
- Imported rows carry the importer's organization and an appropriate owner/branch.
- Import respects the same subtree/org scoping as hand entry.

**Notes:** `[NOTE FOR PM]` the import trigger/cadence for surveys (one-time, periodic, who initiates) is unspecified — tracked with the Voter-import question, **OQ-9-adjacent**.

### 4.6 PR

**Description:** Traditional-media monitoring across six Admin-extensible categories. Most categories share an identical shape, so this is one base record plus two thin detail types. Uses standard toolbar/sidebar-category navigation/export.

**Functional Requirements:**

#### FR-32: PR record capture across categories

A `User` with `write` on PR can create a media-coverage record under one of six categories (Electronic/Print/Local-Print/Local-Electronic/Outdoor/Podcasts-Interviews), capturing title, description, a media platform (from the Admin catalog or a free-text fallback), a URL, sentiment (positive/negative), a publish date, an optional thumbnail, and attachments.

**Consequences (testable):**
- Electronic and Print use the platform catalog; Local-Print/Local-Electronic/Podcasts use the free-text platform fallback.
- Four of six categories need no detail record; they are distinguished by category alone.

#### FR-33: Outdoor-ad counts and podcast recording date

An Outdoor-Media record can carry structured counts per physical ad type (flex, board, pole kiosk, …, an Admin-extensible catalog); a Podcasts/Interviews record can carry a recording date in addition to the publish date.

**Consequences (testable):**
- One Outdoor record can hold several ad-type counts.
- A new outdoor-ad type is addable with just a name, no schema change.

**Notes:** `[NOTE FOR PM]` thumbnail fetching for Electronic Media is an **engineering spike**, not a schema blocker — the field exists; the fetch approach (oEmbed / link-preview / per-platform) is undecided. Tracked as **OQ-10**.

### 4.7 Social Media (v1)

**Description:** With Mainline/Fan-Page Media deferred to v2 (§4.12), this module carries the large-scale, many-pages functionality for v1: the Karyakarta Pages registry, one-click bulk cross-posting with per-post reporting, an Influencers outreach log, Bulk WhatsApp/SMS, and IVRS. This epic owns the Meta Graph API integration work. Realizes UJ-5.

**Functional Requirements:**

#### FR-34: Karyakarta Pages registry

A `User` with `write` on Social Media can register a karyakarta's Facebook/Instagram page, connected via a Meta "connect this Page" OAuth step that stores an encrypted access token. The page owner need not be a system `User` (FK-with-fallback: a `User` reference or free-text name/mobile); the managing team member is tracked separately.

**Consequences (testable):**
- A registered page stores an encrypted token; tokens are never exposed to non-Org-Admin roles.
- A page owner who isn't a system user is still recordable.

#### FR-35: Compose-once, publish-to-many bulk post

A `User` with `write` on Social Media can author a `BulkPost` once (text, image/video, optional link) and fan it out to a target set — all karyakarta pages, a geography/hierarchy-filtered subset, or an explicit multi-select. Realizes UJ-5.

**Consequences (testable):**
- Targeting supports all / geography-filtered / explicit selection.
- Dreamline User can trigger a bulk post under the v1 full-breadth decision (FR-8).

#### FR-36: Asynchronous fan-out with per-target status and retry

Fan-out runs asynchronously (one background job per target page), respects Meta per-app/per-page rate limits, tracks each target independently (pending/success/failed, resulting post ID, error), and surfaces a live status view with individual retry. A single failed/expired-token target does not block others. Realizes UJ-5.

**Consequences (testable):**
- One click starts a job that completes over minutes; a live view shows "N/M published, P pending, F failed — retry."
- A failed target is individually retryable; others still publish.

#### FR-37: Per-post reporting

Once published, each target's post is tracked per page per post with organic reach, paid reach, views, and explicit likes and comments counts (independently queryable, not a single "engagement" number).

**Consequences (testable):**
- Reach, likes, and comments are each separately queryable per post.

#### FR-38: Influencers outreach log (manual, no API)

A `User` can maintain an Influencer directory (name, platform, page URL, relevant assembly, estimated followers) and log manually-entered post results (requested date, post URL, reach/likes/comments, screenshot). No automated metric pull.

**Consequences (testable):**
- Influencer metrics are manual-entry, all nullable; no API integration is attempted.
- An influencer rolls up to Loksabha via its assembly for Loksabha-level orgs.

#### FR-39: Bulk WhatsApp/SMS broadcast

A `User` can broadcast a message, in one action, to multiple named groups or individuals, targeted by geography (village/assembly/loksabha via the constituency link) or by a reusable named contact group, across two channels (WhatsApp and SMS) of one feature. Per-recipient delivery status is tracked (pending/sent/delivered/failed/invalid number). Geography-based audiences are resolved from the Voter roll.

**Consequences (testable):**
- Targeting supports geography, a reusable contact group, or an explicit list.
- "Groups" means named contact lists, not posting into a WhatsApp Group chat (API-impossible).
- Each recipient carries an independent delivery status.

#### FR-40: IVRS voice broadcast with response tracking

A `User` can record (or script via TTS) a message, target it by geography (same scoping as FR-39), and auto-call every matching number, with per-recipient call outcome tracked (delivered / listened fully / listened partial / invalid number / rejected / no answer / busy, with duration).

**Consequences (testable):**
- Each call attempt records an outcome and duration.
- Targeting reuses the geography scoping of FR-39.

**Feature-specific NFRs:** the daily background work and rate-limit discipline here are load-bearing — see §8.2 (job tier sizing) and §8.4 (integrations).

**Notes:**
- `[NOTE FOR PM]` **OQ-3** (how hundreds/thousands of karyakarta pages get connected and kept connected at scale — self-service connect flow vs. Org Admin on their behalf, and expired-token re-connection) must be designed before FR-35/FR-36 can be considered done.
- `[NOTE FOR PM]` **OQ-4**: Bulk WhatsApp/SMS vendor (BSP vs. Meta Cloud API) and IVRS vendor (Exotel/Knowlarity/Ozonetel-style) are external-dependency decisions — they gate the actual *send*, not the schema. Template approval, tiered volume limits, and opt-in/consent for Voter-sourced numbers (§8.3/§8.5) must be confirmed before shipping sends.
- Paid Promotions and Tag Accounts remain generic placeholders (channel/audience/date/response count) in v1 — `[NON-GOAL for MVP: detailed design]`.

### 4.8 Voter Lists

**Description:** Electoral-roll lookup plus voter-sentiment capture tied to Kitchen Cabinet resolution. The most sensitive PII in the system; access is a deliberate, auditable grant with stricter defaults than other modules.

**Functional Requirements:**

#### FR-41: Filtered voter-list lookup

A `User` with access to Voter Lists can filter the roll by State → Loksabha → Assembly → Village → Booth and open a paginated list in the center panel.

**Consequences (testable):**
- Booth is resolved via a real booth reference (booth numbers repeat across assemblies/loksabhas), not a flat number.
- Lists are always paginated — a full-state roll can run into millions of rows; "Get All Details" never renders the whole table.

#### FR-42: Org-owned voter roll

Each organization imports and owns its own copy of the roll (`Voter` is org-scoped, not shared reference data), because per-voter sentiment is org-specific — rival politicians read the same real voter differently.

**Consequences (testable):**
- `Voter` carries `organization_id` and participates in the §4.1 visibility scope.
- Two organizations never share a Voter row for the same real person.

#### FR-43: Voter sentiment status

A Voter carries a mutable sentiment status (`pleased`/`displeased`/`transit`, nullable), set at ticket resolution (FR-22) and changeable later (e.g. pleased → displeased after a bad experience). Green/Amber/Red is a fixed presentation mapping off this enum, not a stored color. Full history comes from the Voter's Tier-1 version history (§4.11).

**Consequences (testable):**
- Sentiment is editable after initial set; each change is versioned.
- No separate color field or status-log table is stored for sentiment.

#### FR-44: PII protection and access control

Voter PII (voter ID, names, mobile numbers) is encrypted at rest; access to the Voter Lists module and any export containing this data is a deliberate, logged, auditable permission grant — stricter than general module `write`.

**Consequences (testable):**
- PII fields are encrypted at rest (not just TLS in transit).
- Every export of voter data logs who/when/which filters.
- Voter Lists access is not bundled into general `write` by default.

**Notes:** `[NOTE FOR PM]` **OQ-9**: how Voter rows actually enter the system (one-time onboarding seed vs. periodic re-sync vs. Org-Admin-triggered import) is unspecified. Recommended default: Admin-or-scoped-import-role bulk Excel/roll import, same tooling as Ground Reports, one-time at onboarding with ad-hoc re-import. `[NOTE FOR PM]` **OQ-11**: whether `Voter`'s remaining flat-text geography fields (state/loksabha/assembly/village) migrate to FK into the hierarchy — recommended default: keep flat text for v1 (reliable name-matching against bulk roll data is its own project), resolve only `booth_id` as an FK (already decided).

### 4.9 RAG Mapping

**Description:** Constituency-level risk/opportunity dashboard — the rollup that turns everything else into a Red/Amber/Green read of each geography. Likely the last module built, since it aggregates the others.

**Functional Requirements:**

#### FR-45: RAG rollup across modules and voter sentiment

A `User` can view a Red/Amber/Green rollup per geography level (village/booth/assembly/constituency), combining Kitchen Cabinet + Ground Reports + Cadre Program activity with a voter-sentiment rollup (counts of pleased/displeased/transit → Green/Amber/Red). This answers "how many votes we got" as a count of Green (pleased) voters at the chosen level.

**Consequences (testable):**
- The rollup presents counts per color per category per geography.
- Voter-sentiment counts feed the same rollup shape.

#### FR-46: RAG presentation views

The module offers Mapped List, Chart, and Dashboard views, with color coding, per-category counts, and chart-based reporting (Bar/Pie/Line, exportable per §4.10).

**Consequences (testable):**
- All three views render from the same precomputed rollup.

#### FR-47: Precomputed rollups

RAG rollups are computed by a background job into a queryable structure (carrying a `computed_at`), not live-aggregated on every page load.

**Consequences (testable):**
- Dashboard load reads precomputed rows, not raw-table aggregates.
- `[NOTE FOR PM]` Mock Poll win-likelihood (FR-30) stays live-computed in v1; revisit a precomputed rollup only if per-village volumes make live computation slow.

### 4.10 Shared UI/Functional Patterns & Dashboards

**Description:** Patterns that recur on nearly every module screen, built as shared reusable components, plus the two-dashboard split.

**Functional Requirements:**

#### FR-48: Shared module chrome

Every module screen presents a shared top bar (app name, logged-in user's photo/name, session timestamp, login count, settings), a module toolbar (Export Excel · Prepare Chart · Bar/Pie/Line toggle · Export Chart · Get All Details), a left sidebar category/entity list acting as in-module filter, and a center data table (per-column filter icons) or report/attachment panel. All of it respects §4.1 scoping.

**Consequences (testable):**
- Toolbar, sidebar, and table are shared components, not per-module reimplementations.
- "Get All Details" means "all details I'm allowed to see," never the raw table.
- Attachments (images/videos/photos) attach to records across modules via a shared mechanism.

#### FR-49: Excel and chart export on every module

Every module can export its currently filtered table to Excel and export the generated chart (Bar/Pie/Line) as an image/PDF; exports are subtree/org scoped and (for Voter data) logged (FR-44).

**Consequences (testable):**
- An export contains only rows the viewer may see.
- Voter-containing exports are logged with who/when/filters.

#### FR-50: Single shared Organization Dashboard

Org Admin, User, Dreamline User, and any other `User`-side role share one widget-composed Organization Dashboard. Each widget's query runs through the same §4.1 scoping, and whether a widget renders at all reuses the module permission check — a role with no access to a module simply doesn't get that widget. There is no role-specific dashboard code.

**Consequences (testable):**
- A role with `none` on Voter Lists sees no voter widget.
- Org Admin and Dreamline User see the same framework with naturally different content, driven only by permissions/scope.

#### FR-51: Org-admin-only dashboard widgets

Org Admin additionally sees a small set of org-admin-only widgets not tied to a module — pending items needing attention, a hierarchy/user-count summary, and a recent-deletions feed (from the audit trail) — gated by the `org_admin`/`can_create_users` capability rather than a module permission.

**Consequences (testable):**
- The org-admin-only widgets render only for roles with the capability.
- The recent-deletions feed reflects soft-deletes from the audit trail.

### 4.11 Audit History & Change Tracking

**Description:** Two tiers matched to what's useful per table, plus a cross-table activity index. Not a blanket diff-everything policy.

**Functional Requirements:**

#### FR-52: Tier-1 full version history

Records where field-level history matters (Voter PII edits, User and role-permission changes, and candidate records such as ground-report content edits) carry full version history, each in its own dedicated per-model version table (not one shared table). A soft delete is recorded as an ordinary tracked update so the trail survives archiving.

**Consequences (testable):**
- "Show this record's full history" is a direct lookup by record ID.
- A soft-deleted record's version trail continues past the delete.
- `[NOTE FOR PM]` **OQ-5**: whether GroundReport resolution and bulk-post-target status also get history, and at which tier, is undecided table-by-table.

#### FR-53: Tier-2 lightweight status-transition log

Workflow tables where status is what matters (confirmed: Ticket) log one row per status change (from/to/actor/timestamp), not per field edit. "Who created it" / "who soft-deleted it" are answered by plain owner/creator and discarded-by columns, not a version table.

**Consequences (testable):**
- Resolution time is derivable by diffing consecutive status-change timestamps.

#### FR-54: Cross-table activity index

A small, append-only activity index records "who did what, where" across the platform (actor + type, action, record type/id, organization, timestamp — no full diff), including every `Admin` cross-org access (§8.1).

**Consequences (testable):**
- "Show everything this person did, anywhere" is answerable without querying N per-model version tables.
- Admin cross-org access appears in this index.

### 4.12 Mainline/Fan-Page Media — deferred to v2

**Description:** Facebook/Instagram page tracking for Official/Fan/Opposition Pages and Comparisons, with automated daily Meta Graph API metric collection and a Reach Dashboard. `[NON-GOAL for MVP]` — the entire module moves to v2. The underlying page/metric/post entities are still built in v1 (they serve Karyakarta Pages, §4.7); v2 points them at more page types with no schema change, and reuses §4.7's Graph API plumbing. Sequence after §4.7, not before.

## 5. Non-Goals (Explicit)

- **Not a party platform.** SAC-PAD targets individual politicians; parties are reference data, never tenants.
- **Not multi-constituency per organization.** An organization contests exactly one Loksabha or Assembly seat at a time.
- **No self-service sign-up** on either scope; no public/constituent accounts.
- **No hard deletes** of domain data — ever. Soft delete only, Org Admin / Admin only.
- **No Org-Admin-defined custom roles in v1.** Role definition is Admin-only; Org Admin only assigns.
- **No 2FA in v1** on either scope (deferred to Phase 2; revisit as mandatory on the `Admin` scope once real voter data is live).
- **Mainline/Fan-Page Media, Targets, Paid Promotions (detailed), Tag Accounts (detailed), and the Info / Village-wise Reports nav tabs are not built in v1.**
- **No automated metrics for pages/influencers the org doesn't control** — opposition and influencer numbers are manual (and opposition comparisons are a v2 concern anyway).
- **Not promising a 100%-leak-proof system** — the goal is to make a cross-tenant leak require multiple independent failures, not one missed clause.

## 6. MVP Scope

### 6.1 In Scope
- Foundation: separate `Admin` account type + Platform Console; `User`-side organizations/auth/roles/permissions (Admin-managed) + `can_create_users`; unlimited-depth hierarchical user management; deactivation cascade; defense-in-depth tenant isolation + its mandatory test suite; the two-tier audit + cross-table activity index; geography hierarchy + organization↔constituency link; org-scoped `Politician` roster.
- Kitchen Cabinet (categories, status workflow + status log, follow-up log, voter-ID-gated-on-closure, sentiment capture on resolution).
- Cadre Program (six categories: base + detail).
- Ground Reports (village-centric sub-sections + Excel import for Report and Mock Poll; composite geography/org uniqueness).
- PR (categories, base + two detail types, media-platform and outdoor-ad-type catalogs).
- Social Media v1 (Karyakarta Pages registry + bulk cross-posting with per-post reporting; Influencers manual log; Bulk WhatsApp/SMS; IVRS — vendors TBD).
- Voter Lists (org-owned roll, booth FK, sentiment, PII encryption + stricter access + logged exports).
- RAG Mapping (precomputed rollup of modules + voter sentiment; Mapped List / Chart / Dashboard).
- Cross-cutting: shared toolbar/sidebar/table components; Excel/chart export everywhere; shared Organization Dashboard + org-admin widgets; geography reference data; the infra posture in §8.2; a pre-launch security review.

### 6.2 Out of Scope for MVP
- **Mainline/Fan-Page Media (v2)** — reuses v1's Graph plumbing; sequence after Social Media v1. `[NOTE FOR PM: load-bearing for the politician's "reach" narrative — revisit timing.]`
- **Targets module** — no schema or UI; nav tab omitted/stubbed.
- **Info / Village-wise Reports nav tabs** — no screens provided (**OQ-1**); treat as "skip for v1" unless a requirements pass lands first.
- **Paid Promotions / Tag Accounts detailed design** — generic placeholder only.
- **2FA** — Phase 2.
- **Org-Admin self-service custom roles** — schema supports it later; no UI in v1.
- **Module-level narrowing of Dreamline User** — later-phase data change.
- **WhatsApp Group posting** — API-impossible; "groups" = named contact lists.

## 7. Success Metrics

**Primary**
- **SM-1: Zero cross-tenant leaks.** No incident in which one organization's user accesses another's data. Target: zero, continuously; measured by the mandatory isolation test suite (FR-11) passing on every release plus production access-audit review (FR-54). Validates FR-10, FR-11, FR-2, FR-9.
- **SM-2: Proof-of-help capture rate.** Share of `closed` Kitchen Cabinet tickets that carry a `voter_id` (and therefore a sentiment). Target set with stakeholder; the ratio measures whether the resolution→voter loop (the product's core value) is actually being closed in the field. Validates FR-21, FR-22, FR-43.
- **SM-3: Field adoption.** Weekly active `User`s logging records (tickets, cadre activity, ground reports) as a share of provisioned users. Validates FR-19, FR-24, FR-27, FR-4.

**Secondary**
- **SM-4: Bulk-post delivery success.** Share of `BulkPostTarget`s reaching `success` on first attempt; stale/expired-token pages surfaced within one sync cycle. Validates FR-34, FR-36, FR-37.
- **SM-5: Dashboard freshness/latency.** RAG and dashboard views load within target latency at the expected peak, reading precomputed rollups. Validates FR-47, FR-50, and §8.2.
- **SM-6: Sentiment coverage.** Share of a constituency's voters with a non-null sentiment, as the RAG "votes we got" signal matures. Validates FR-43, FR-45.

**Counter-metrics (do not optimize)**
- **SM-C1: Do not inflate proof-of-help capture (SM-2) by relaxing the closure gate.** If `voter_id` capture rate rises because tickets are being closed prematurely or the resolution gate (FR-21) is weakened, that is a regression, not a win. Counterbalances SM-2.
- **SM-C2: Do not raise bulk-send volume (SM-4) past consent/compliance limits.** Delivery success must not be pursued by messaging non-opted-in numbers or exceeding approved template/volume limits (§8.3/§8.5). Counterbalances SM-4.
- **SM-C3: Do not broaden Voter Lists access to lift sentiment coverage (SM-6).** PII access must stay a deliberate, stricter grant (FR-44); coverage gained by loosening it is a loss. Counterbalances SM-6.

## 8. Cross-Cutting Non-Functional Requirements

### 8.1 Security & Tenant Isolation (critical)
- Defense in depth, not one layer: per-action policy scoping **and** a denormalized `organization_id` on every domain table **and** a model-layer auto-scoping safety net that refuses unscoped queries **and** DB-level `NOT NULL` + FK constraints. For Voter Lists specifically, evaluate Postgres Row-Level Security as an additional DB-enforced layer.
- `Admin` cross-org visibility is not a bypass flag inside the shared code path; `Admin` is a separate account type whose Console queries are explicit and separately logged (FR-54, FR-17).
- Mandatory cross-tenant isolation tests are a release blocker (FR-11): expect 404 (not 403) on cross-tenant access, for every module.
- Credential-stuffing/brute-force resistance via login rate-limiting and account lockout on both scopes; no self-service password reset on the `Admin` scope (out-of-band recovery).
- A security review / pen-test pass before launch with real voter data, budgeted as its own pre-launch task.

### 8.2 Scalability & Performance (target: 10,000 concurrent users)
- Horizontally-scaled app tier (clustered workers behind a load balancer, autoscaled on CPU/latency), sized by load testing, not guessed.
- Connection pooling (transaction-pooling proxy) in front of Postgres before load testing — the most common failure point at this scale.
- Separate databases for background jobs / cache / cable from the primary OLTP database.
- Read replica(s) for heavy-read paths (dashboards, exports, Voter lookups).
- Cache the subtree lookup (FR-4) — the one calculation on nearly every authorized request; invalidate only on hierarchy change.
- Precompute, don't live-aggregate, the rollup dashboards (FR-47).
- Paginate every listing; Voter Lists especially can run into millions of rows.
- Deliberate indexing: `organization_id`/`owner_id` on every domain table, the hierarchy/closure columns, and composite indexes on actually-filtered columns (geography, date ranges).
- CDN in front of stored media; don't serve files through the app.
- Size background-job workers independently of the web tier (the social sync/bulk-publish fan-out must not starve time-sensitive jobs like export generation).
- Observability from day one (APM — Datadog is available to the org — plus Postgres slow-query logging) so regressions are caught in staging.
- Load test before launch against the real usage shape (see **OQ-7**: what "10,000 concurrent" actually means — idle sessions vs. simultaneous submissions vs. peak RPS).

### 8.3 Data Governance & Privacy
- Voter ID, mobile numbers, and personal details are PII: field-level encryption at rest, deliberate/auditable access grants, logged exports (FR-44).
- All domain deletes are soft deletes; no domain data is ever hard-deleted (recoverable, audited).
- Stored external-service access tokens are encrypted and never exposed to non-Org-Admin roles.

### 8.4 Integrations & External Dependencies
- **Meta Graph API** (Facebook Pages + Instagram Business) over HTTP, using batch calls where possible; daily metric sync must be idempotent, tolerate per-page failures without aborting the batch, and alert on expired/revoked tokens. (Daily sync is v2 for Mainline/Fan-Page; v1 uses the API for Karyakarta Pages publish + per-post reporting.)
- **WhatsApp/SMS vendor** (BSP vs. Meta Cloud API) and **IVRS vendor** — undecided; they gate the actual send, not the schema (**OQ-4**).
- Each integration's rate limits are a first-class operational constraint (FR-36, §8.2 job sizing).

### 8.5 Compliance & Regulatory (not legal advice — flagged for legal review)
- Handling voter PII and sending political communications is subject to data-protection and election-communication rules that vary by jurisdiction (e.g. India's DPDP Act; separate rules on unsolicited bulk messaging). Requires an actual legal/compliance review before launch.
- Consent/opt-in for numbers sourced from the Voter roll (FR-39/FR-40), WhatsApp template approval, and tiered volume limits must be confirmed before any send ships.

### 8.6 Operational / Reliability
- Every login records a timestamp and increments a login counter (shown in the top bar).
- Every create/update is timestamped and attributable; see §4.11 for the audit tiers.
- The daily social sync job is idempotent (safe to re-run for the same day without duplicate snapshots) and alerts on token expiry.

## 9. Open Questions

Carried from the brief §9/§10 per the chosen Fast-path handling. Each has a recommended default so planning isn't blocked; resolve or defer-with-owner at finalize.

- **OQ-1 — Info / Village-wise Reports nav tabs (brief §9 #5).** No screens provided. *Recommended default:* skip for v1 (same as Targets) until a requirements pass defines them.
- **OQ-2 — Meta coverage for Opposition Pages / Comparisons (brief §9 #11).** Now a v2 concern (module deferred). *Recommended default:* in v2, manual entry of public numbers where the API can't reach unmanaged pages.
- **OQ-3 — Connecting hundreds/thousands of karyakarta pages at scale (brief §9 #13).** Self-service connect vs. Org-Admin-on-behalf; expired-token re-connection workflow. *Recommended default:* self-service connect flow + a token-health surface in the Platform Console (FR-18) and Org Dashboard; design before FR-35/FR-36 are "done."
- **OQ-4 — Bulk WhatsApp/SMS and IVRS vendors (brief §9 #14).** *Recommended default:* pick one WhatsApp BSP (or Meta Cloud API) and one IVRS vendor during architecture; keep the schema vendor-agnostic (already is).
- **OQ-5 — History tier for GroundReport resolution and bulk-post-target status (brief §9 #16).** *Recommended default:* Tier-2 lightweight status log for both; revisit if field-level history is later needed.
- **OQ-6 — `ops`-tier Admin access level within assigned organizations (brief §9 #20).** Full-equivalent (incl. delete) vs. limited/read-only. *Recommended default:* full-equivalent within assigned orgs, minus platform-wide settings; revisit before onboarding external ops staff.
- **OQ-7 — What "10,000 concurrent users" means (brief §9 #15).** *Recommended default:* model a realistic mix (frequent small field reads/writes + occasional heavy dashboard/export) and load-test that before launch; pin the peak with the stakeholder.
- **OQ-8 — `can_create_users`: keep as a dormant flag or hardcode to `org_admin` (brief §9 #24).** *Recommended default:* keep the flag (it costs little and preserves the delegation path); default only `org_admin` true.
- **OQ-9 — How Voter rows enter the system (brief §6.7).** *Recommended default:* Admin-or-scoped-import-role bulk Excel import at onboarding, with ad-hoc re-import; same tooling as Ground Reports.
- **OQ-10 — Thumbnail fetching for Electronic Media PR (brief §6.4).** Engineering spike, field already exists. *Recommended default:* oEmbed/link-preview service first, per-platform scraper only if needed.
- **OQ-11 — Voter flat-text geography → FK migration (brief §9 #34).** *Recommended default:* keep flat text for v1 (only `booth_id` is an FK); migrate later only if reliable name-matching proves worthwhile.
- **OQ-12 — Where else the `Politician`/opponent link applies (brief §9 #33).** Confirmed for Mock Poll and Opposition Pages; stakeholder hinted at "other places." *Recommended default:* ship the two confirmed uses; add links as concrete needs are named.

## 10. Assumptions Index

Every inline `[ASSUMPTION]` surfaced for explicit confirmation:
- **§4.1 / FR-5** — The eight modules in the Glossary are the complete v1 permission surface; Mainline/Fan-Page Media stays in the enum though its UI is v2.
- **§4.1 / FR-7** — For v1 the effective user-creation rule is "only `org_admin`"; the `can_create_users` mechanism's fate is OQ-8.
- **§4.2 / FR-14** — System/seeded roles are marked and protected from accidental deletion; exact edit rules TBD.
- **§6 stakes calibration** — SAC-PAD is treated as launch-grade (real voter PII, rival tenants, 10k concurrent, DPDP/election-comms exposure); PRD rigor is set accordingly. Confirm this matches the intended v1 ambition.
- **Output/vocabulary** — "SAC-PAD" and "Organization" are retained as the product/model names (per brief §9 #19); confirm the working title.

---

*Downstream: `bmad-ux` (screen/flow design for the modules and the two dashboards), `bmad-create-architecture` (Rails 8 structure, two Devise scopes, Pundit conventions, closure-tree subtree scoping, tenant-isolation layering, audit tiers), then `bmad-create-epics-and-stories` (the brief's §10 epic breakdown maps directly onto §4 here). Invoke `bmad-help` for authoritative routing.*
