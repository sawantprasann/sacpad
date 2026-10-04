# SAC-PAD PRD — Addendum (technical-how & downstream depth)

This addendum preserves depth from the source brief (`docs/project_brief.md`) that is load-bearing for **architecture / solution-design** but does not belong in the capability-level PRD. The brief remains the canonical, fuller source; this is the curated hand-off of the technical decisions already made, plus rejected alternatives and their rationale, so they are not re-litigated downstream.

> Primary source: `../../project_brief.md` (SAC-PAD Project Specification). Where this addendum and the brief differ, the brief wins; flag the drift.

## 1. Tech stack (brief §2) — decisions, not options
- **Framework / DB / styling:** Ruby on Rails 8, PostgreSQL, TailAdmin (Tailwind admin template).
- **Auth:** Devise with **two separate scopes** — `devise_for :users, path: ''` (org-facing, clean root path) and `devise_for :admins, path: 'console'` (deliberately non-obvious, unlinked). Modules: `User` = database_authenticatable/recoverable/rememberable/trackable/lockable(`:both`), no registerable; `Admin` = database_authenticatable/trackable/lockable(`:time`), no registerable, no recoverable (out-of-band recovery). 2FA (`devise-two-factor`) deferred to Phase 2 on both scopes.
- **Authorization:** Pundit (policies scoped by role + hierarchy subtree).
- **Hierarchy:** `closure_tree` (chosen over `ancestry` at the 10k-concurrent scale — indexed ancestor/descendant pairs hold up better under concurrent subtree lookups than materialized-path string matching). Each user's `subtree_ids` cached (Solid Cache/Redis), invalidated only on hierarchy change.
- **Tenant isolation:** `acts_as_tenant` as a model-layer safety net on top of Pundit + denormalized `organization_id`; raises on unscoped queries. Evaluate Postgres RLS for Voter specifically.
- **Files:** Active Storage (polymorphic `has_many_attached`); CDN (CloudFront/Fastly over S3) in front.
- **Charts:** Chartkick + Chart.js (Groupdate for time-series). **Excel:** export `caxlsx`, import `roo`/`creek`.
- **Jobs:** Solid Queue (recurring via `config/recurring.yml`); separate DBs for Solid Queue/Cache/Cable from primary OLTP.
- **Soft delete:** `discard` (Org-Admin/Admin only; every delete recoverable).
- **Versioning:** `paper_trail` with **custom per-model version classes** (`VoterVersion`, `UserVersion`, `RolePermissionVersion`, …) — one table per tracked model, not one shared `versions` table. Lightweight `TicketStatusChange`-style log for status-only tracking.
- **External APIs:** Meta Graph API over `Faraday`/`HTTParty` (Batch API where possible; no wrapper gem — `koala` lags Meta's versioning). WhatsApp Business/Cloud API (deferred vendor). IVRS vendor TBD.
- **Credential/PII storage:** Rails 8 Active Record Encryption (`encrypts`) for Page tokens and Voter PII.
- **Scale infra:** PgBouncer (transaction pooling); Pagy pagination everywhere; Bullet (N+1, dev/staging); Datadog APM + Postgres slow-query logging from day one.

## 2. Data model (brief §7) — canonical table list
The full draft data model (every table + columns) is in brief §7 and §7a. Not duplicated here; architecture should take it verbatim as the starting schema. Key structural decisions worth surfacing:
- `Admin` is a standalone table (no `organization_id`/`parent_id`/`role_id`); `AdminOrganization` join scopes `ops`-tier admins.
- `Organization` → polymorphic `constituency_id`/`constituency_type` (`Loksabha`|`Assembly`), fixed for lifetime (not history-preserving). `villages`/`assemblies` derived via the branch logic in brief §3.1c (not a plain `has_many`).
- `party_memberships` history-preserving; `Organization.current_party_id` denormalized fast-pointer (nil = Independent).
- Geography: `State → Loksabha → Assembly → Village → Booth`, global/Admin-managed reference data. `Booth` is an FK target (booth numbers repeat across assemblies).
- Org-scoped village content tables need **composite `(village_id, organization_id)` uniqueness**, never `village_id` alone.
- Cadre Program: `CadreActivity` base + 5 detail tables (2 categories share a shape). PR: `PrRecord` base + 2 detail types (`PrRecordOutdoorAdCount`, `PrRecordPodcast`); 4 of 6 categories need no detail.
- `Voter` is org-scoped (each org owns its imported copy); `booth_id` FK; other geography stays flat text in v1 (OQ-11).
- `Politician` org-scoped (not global); partial-unique `is_own_politician`; name kept in sync with `Organization.name` via callback.
- `SocialPage`/`SocialPageMetricSnapshot`/`SocialPagePost` built in v1 for Karyakarta Pages, reused by v2 Mainline/Fan-Page with no schema change.
- "Inherited-scope" child tables (targets, snapshots, posts, members, call attempts) must always be queried through their tenant-scoped parent, never standalone by ID.

## 3. Rejected alternatives / corrections (brief §9) — do not re-open
- **`SuperAdmin` → `Admin` (and org role → `org_admin`):** naming collision resolved by renaming the org-level role, freeing the plain name `Admin` for the platform account type. "Organization" considered-and-kept (not renamed to "Client").
- **Admin as a `User` row with `organization_id: nil`:** rejected in favor of a genuinely separate table — makes a cross-tenant leak architecturally impossible rather than a nil-check to get right every time.
- **`ancestry`:** rejected for `closure_tree` at this scale.
- **Six independent Cadre tables / one wide table:** rejected for base+detail (avoids 6× duplicated scoping/audit and avoids dozens of null columns).
- **Six PR detail tables:** rejected — four categories are identical in shape; only Outdoor and Podcasts need detail.
- **Village karyakartas as `User` rows with `village_id`:** rejected/corrected — they aren't system users; split into `VillageLocalKaryakarta` + `VillageLocalAdminContact`.
- **Separate loksabha_id + assembly_id + office_level on Organization:** rejected for the polymorphic constituency pair.
- **Stored RAG color field / separate sentiment status-log table:** rejected — color is a presentation mapping off the sentiment enum; history comes from the Tier-1 Voter version table.
- **Separate Mock Poll tally table:** rejected for v1 — win-likelihood is a read-time group-by.

## 4. Epic breakdown (brief §10) — maps onto PRD §4
The brief's suggested epics map directly onto this PRD's feature groups and should seed `bmad-create-epics-and-stories`:
- **Epic 0** = PRD §4.1 + §4.2 + §4.11 + geography/constituency + `Politician` roster + the §8.1/§8.2 infra posture (foundation; everything depends on it; highest-stakes).
- **Epic 1** = §4.3 Kitchen Cabinet. **Epic 2** = §4.4 Cadre Program. **Epic 3** = §4.5 Ground Reports. **Epic 4** = §4.6 PR.
- **Epic 4a** = §4.7 Social Media v1 (owns the Meta Graph API integration). **Epic 4b** = §4.12 Mainline/Fan-Page Media (v2, after 4a).
- **Epic 5** = §4.8 Voter Lists. **Epic 6** = §4.9 RAG Mapping (last; aggregates the others).
- **Cross-cutting infra** (sequence early, Epic 0 depends on parts): PgBouncer + multi-DB split, Pagy everywhere, `subtree_ids` caching, precomputed dashboard rollups, CDN, APM, pre-launch load test (OQ-7) and security/pen-test pass.

## 5. Architecture doc should lock in (brief §10 #4)
Rails 8 structure with the two Devise scopes/controller namespaces; TailAdmin integration; Pundit policy conventions; the organization → module-permission → `closure_tree` subtree scoping pattern (brief §3.4); the dashboard widget-composition pattern (brief §5a); the two-tier audit/versioning approach (brief §7a). Nearly every controller/policy across every epic reuses these.
