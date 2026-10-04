---
name: SAC-PAD
status: draft
created: 2026-10-04
updated: 2026-10-04
sources:
  - ../../prds/prd-sacpad-2026-10-04/prd.md
  - ../../prds/prd-sacpad-2026-10-04/addendum.md
  - ../../project_brief.md
design_ref: ./DESIGN.md
scope: Platform Console + Kitchen Cabinet ticket flow (this run). Other modules follow in later UX runs.
---

# SAC-PAD — Experience Spine

> Scope of this draft: the **Platform Console** (operator) and the **Kitchen Cabinet ticket flow** (field user), plus the shared foundation both inherit. Visual identity lives in `DESIGN.md`; this spine owns how it works. Spines win on conflict with any mock or import.

## Foundation

SAC-PAD is a multi-tenant Rails 8 + TailAdmin web app with **two distinct experiences in one product**:

- **Org side** — party-themed, **mobile-first for field capture** (Kitchen Cabinet) scaling up to desktop. Audience: the campaign's cadre, from Org Admin down to karyakarta, each seeing only their own hierarchy subtree.
- **Platform Console** — neutral steel operator skin, **desktop-primary**, reached only through the separate, unadvertised `/console` login. Audience: the platform operations team (`Admin`), never a campaign.

`DESIGN.md` is the visual identity reference and names the token surface; this spine specifies behavior. Every Org-side surface is scoped by organization → module permission → hierarchy subtree (PRD §4.1); the Console is scoped by Admin tier (`full` = all orgs, `ops` = assigned orgs). TailAdmin does the component heavy lifting; SAC-PAD specifies only the behavioral delta.

## Information Architecture

### Org side (party-themed) — Kitchen Cabinet in focus

| Surface | Reached from | Purpose |
|---|---|---|
| Organization Dashboard | Login / home | Widget-composed overview; widgets render per the viewer's module permissions + subtree (PRD FR-50/FR-51). Entry point to every module. |
| Kitchen Cabinet — category list | Dashboard / left sidebar | The module's left sidebar lists the 12 (Admin-managed) categories; tapping one filters the center list. On mobile this is the module's landing screen. |
| Kitchen Cabinet — ticket list | A category, or "All" | Center panel: desktop = filterable table; mobile = `ticket-card` list. Scoped to the viewer's subtree. Module toolbar (Export/Chart/Get All Details) sits here. |
| Ticket detail | A ticket row/card | The full record: fields, attachments, the `voter-gate-field`, the **follow-up action log**, and the status control. The workhorse screen. |
| New / edit ticket | FAB (mobile) / "New ticket" (desktop) | Capture form, pre-filled to the active category. |
| Closure flow | "Close" on a ticket | The gated moment: confirm resolution → unlock `voter_id` → `sentiment-picker`. |

Mobile: the module uses a **three-level drill** (category list → ticket list → ticket detail) with a persistent FAB. Desktop: the classic TailAdmin **sidebar (categories) + center table + detail** shell, no drill needed.

### Platform Console (neutral operator skin)

| Surface | Reached from | Purpose |
|---|---|---|
| Organizations list | Console home | All orgs (or assigned, for `ops`) with health: active/inactive, user counts, last activity (PRD FR-13). |
| Create organization | Organizations list | Wizard: org identity → constituency (one Loksabha *or* Assembly) → party affiliation → first Org Admin → seed Politician roster. |
| Organization detail | An org row | Operator view *into* one org — fires the `console-org-banner` (logged access). Drill to that org's data for support. |
| Role & permission catalog | Console nav | Create/edit roles, per-module access levels, `can_create_users` (PRD FR-6/FR-14). The only place roles are defined. |
| Reference-data editors | Console nav | Parties, geography (State→Loksabha→Assembly→Village→Booth), ticket categories, PR categories, media platforms, outdoor-ad types (PRD FR-15). |
| Cross-org audit log | Console nav | Who did what, where — including every Admin cross-org access (PRD FR-17/FR-54). |
| Platform health | Console nav | Sync-job success, queue depth, external rate-limit/token headroom (PRD FR-18). |

Console nav uses TailAdmin's sidebar. An `ops`-tier Admin sees a filtered Organizations list and every downstream view scoped to assigned orgs only.

→ Composition references will be rendered at Finalize to `mockups/`. Spine wins on conflict.

## Tenant Identity & Theming *(SAC-PAD-specific)*

- On login, the Org-side shell resolves the organization's Party color + logo and applies them per `DESIGN.md` (accent + header logo only). Independent orgs use the fallback accent and the SAC-PAD mark.
- The theme is a **signal of belonging, not of data scope** — it tells a user "this is *your* campaign's tool." It never implies cross-org visibility; scope is always enforced underneath regardless of theme.
- The Platform Console **never themes**. Its steel skin is a constant. An `Admin` switching from the Console into an org's data keeps the Console chrome and gains the audit banner — they are visiting, not inhabiting, that org.
- Two rival orgs in the same constituency will look different from each other (different party accents) and both different from the Console — the at-a-glance "whose tool am I in" cue the product needs.

## Audit & Consequence Signals *(SAC-PAD-specific)*

- Whenever an `Admin` opens a specific organization's data, the `console-org-banner` is shown for the duration: "You're viewing {Org}'s data. This access is logged." It is persistent (not a dismissible toast) while inside that org (PRD FR-17, §8.1).
- Soft-delete is never silent: a delete asks for confirmation, states it's recoverable, and surfaces in the Org Admin's recent-deletions widget (PRD FR-51) and the audit trail (FR-54).
- The voter-ID gate (below) is itself a consequence signal: the UI makes visible *why* the field is locked, so the rule reads as intent, not a bug.

## Voice and Tone

Microcopy. Brand posture lives in `DESIGN.md`. SAC-PAD talks like a calm, competent desk officer — plain, respectful of the stakes, never cute. English-only v1.

| Do | Don't |
|---|---|
| "Log an issue" | "Add a ticket 🎫" |
| "Voter ID unlocks once this issue is closed." | "You can't do that yet." |
| "Mark how this voter feels now." (pleased / transit / displeased) | "Rate satisfaction 1–5" |
| "You're viewing {Org}'s data. This access is logged." | "Admin mode" |
| "Resolved. This is now on record as help delivered." | "Task completed successfully ✓" |
| "This issue is blocked — note why in a follow-up." | "Error: cannot close" |
| Neutral, specific, person-centred (an issue belongs to a *person in a village*) | Campaign-slogan energy anywhere in the chrome |

## Component Patterns

Behavioral rules; visual specs in `DESIGN.md.Components`.

| Component | Use | Behavioral rules |
|---|---|---|
| ticket-card (mobile) | KC ticket list | Whole card taps through to detail. Shows person + village, category icon, `status-pill`, reported date. No swipe actions in v1. |
| ticket table row (desktop) | KC ticket list | Row click opens detail. Per-column filter icons (shared chrome). "Get All Details" = all rows the viewer may see, paginated — never the raw table. |
| status-pill | Ticket card/row/detail | Reflects open/in_progress/closed/blocked. Read-only display; status is changed via the status control on detail, which logs every transition (Tier-2, FR-53). |
| voter-gate-field | Ticket detail | Visible always. Locked (disabled + lock glyph + helper copy) unless status=closed. Attempting entry while locked does nothing but re-show the helper — the model also rejects it (FR-21). |
| follow-up log | Ticket detail | Append-only, timestamped, attributed entries with optional attachment (FR-23). Newest first. Any role with KC `write` can add. Distinct from the bare status-change history. |
| sentiment-picker | Closure flow | 3-segment control; selection writes to the matched Voter (FR-22/FR-43). Mutable later from the Voter record (out of this run's scope). |
| category sidebar item | KC landing | Tap filters the list and pre-fills "new ticket" to that category. Reference-data-driven; a new Admin-added category appears with no deploy. |
| module-toolbar | Every module list | Export Excel · Prepare Chart · Bar/Pie/Line · Export Chart · Get All Details. Exports are subtree/org-scoped. |
| console-org-banner | Console → org data | Persistent while inside an org. Not dismissible. |
| create-org wizard | Console | Linear, resumable steps; constituency is set once and is a hard choice (one Loksabha OR one Assembly). Provisions ≥1 Org Admin before finishing (FR-13). |
| role editor | Console | Matrix of module × access-level (none/read/write) + `can_create_users` toggle. System roles flagged and protected `[ASSUMPTION: exact edit/delete rules for system roles TBD — OQ adjacent]`. |

## State Patterns

| State | Surface | Treatment |
|---|---|---|
| Cold load | Any list | TailAdmin skeleton rows matching expected layout. |
| Empty category | KC ticket list | "No issues logged under {Category} yet." + primary "Log an issue" (party-accented). |
| Voter ID locked | Ticket detail | `voter-gate-field` disabled with inline helper: "Voter ID unlocks once this issue is closed." No error styling — this is normal, not a failure. |
| Closing a ticket | Closure flow | Step 1 confirm resolution + closure date → Step 2 optional match a voter and set sentiment. Closing without a voter is allowed (helper notes the proof-of-help benefit of adding one). |
| No voter match | Closure flow | "No voter found for that ID in this org's roll." Allow close anyway; `voter_id` is a loose lookup, not an FK (FR-21). |
| Blocked ticket | Ticket detail | `status-pill` blocked + a prompt to record the blocker as a follow-up entry. |
| Permission denied (module) | Dashboard / nav | The module's widget and nav entry simply don't render (FR-50). No "access denied" screen. |
| Cross-tenant access attempt | Any | Returns not-found, never a 403 that would confirm the record exists (PRD FR-11/§8.1). UI shows a generic "Not found." |
| Admin viewing an org | Console org detail | `console-org-banner` persistent for the whole visit. |
| `ops` Admin out of scope | Console | Orgs outside assignment are absent from the list, not shown-and-locked. |
| Deactivated org (live session) | Org side | Next action returns the user to a neutral "This organization is no longer active" screen; no data renders (FR-9). |

## Interaction Primitives

**Touch-first on the Org/ticket side; pointer-first in the Console.**

- **Mobile ticket flow:** FAB = "log an issue" from anywhere in the module. Back navigates up the three-level drill. Targets ≥ 44px. No swipe-to-act, no hover-only affordances, no drag in v1.
- **Desktop:** row-click to open; per-column filters; keyboard `Tab` order follows reading order; `Esc` closes the topmost modal/sheet.
- **Closure is a deliberate two-step**, never a single toggle — the voter-ID + sentiment moment is consequential and should feel it, without nagging confirmations elsewhere.
- **Banned everywhere:** infinite scroll (pagination only — lists can be huge), hover-only affordances on touch, modal stacks > 1 deep, silent destructive actions.

## Accessibility Floor

Behavioral; visual contrast in `DESIGN.md`.

- WCAG 2.2 AA across both skins, at mobile and desktop widths.
- **RAG/sentiment never by color alone** — every `rag-chip` carries a label (Pleased/Transit/Displeased) and the `status-pill` carries both a dot and text, so color-blind users and the party-accent layer can't collapse meaning.
- Party accent foreground is auto-verified for AA; a party hue that can't reach AA is clamped (`DESIGN.md`).
- Screen reader announces surface on navigation ("Kitchen Cabinet, {Category}, {N} issues"; "Platform Console, Organizations").
- The locked `voter-gate-field` announces its locked state and the unlock condition, not just "disabled."
- Every interactive target keyboard-reachable; focus ring uses the accent/ring token at AA against the surface.

## Responsive & Platform

| Breakpoint | Org / Kitchen Cabinet | Platform Console |
|---|---|---|
| `≥ lg` (1024px+) | TailAdmin sidebar (categories) + center table + detail pane. | Full operator layout; primary target. |
| `md` (768–1023px) | Sidebar collapses to icons; table stays; detail as overlay. | Usable, sidebar collapses. |
| `< md` (`sm`) | **Primary design target for KC:** three-level drill (category → list of `ticket-card`s → detail), persistent FAB, bottom-sheets for category/sentiment pickers. | Not optimized in v1 (`[NON-GOAL for MVP]`); renders but desktop is expected. |

## Inspiration & Anti-patterns

- **Lifted from TailAdmin:** the entire component and layout vocabulary — sidebar, data tables, form controls, cards, dashboard widgets. SAC-PAD's identity is *what we layer on TailAdmin* (party theming, RAG semantics, the two skins), not a from-scratch system.
- **Rejected — one themed look for the Console too:** the operator must never mistake the operator view for a campaign dashboard; the steel skin + audit banner is a safety feature, not decoration.
- **Rejected — letting party color flow into surfaces/charts freely:** rival-tenant product; an unbounded accent risks clashing with RAG semantics and breaking contrast. Accent is bounded by contract.
- **Rejected — closing a ticket as a one-tap status toggle:** the resolution → voter-ID → sentiment beat is the product's core value event and is deliberately a two-step flow.
- **Rejected — celebratory confetti on closure:** the stakes are real constituents; the confirmation is quiet and factual ("on record as help delivered"), not a game reward.

## Key Flows

### Flow 1 — Rohan logs and later resolves a grievance (mobile, in the field)

1. Rohan, a taluka karyakarta, opens SAC-PAD on his phone; the shell is themed in his politician's party color. He lands on the Organization Dashboard, taps **Kitchen Cabinet**.
2. The category list appears. A farmer is in front of him about a blocked subsidy — he taps the **FAB** ("Log an issue"); the new-ticket form opens pre-filled to **Farmers** (he picked that category).
3. He enters the farmer's name + village + mobile, a short description, snaps a photo of the paperwork, saves. Status defaults to **open** (a subtle slate pill). The `voter-gate-field` sits visibly **locked** with the helper "Voter ID unlocks once this issue is closed."
4. Over the next weeks he returns to the ticket and adds **follow-up** entries as the team works it; status moves to **in_progress** (blue pill). Each change is logged.
5. **Climax:** the subsidy clears. Rohan opens the ticket, taps **Close** → confirms the resolution and closure date. The `voter-gate-field` **unlocks**; he enters the farmer's voter ID, the matched voter surfaces, and the **sentiment-picker** asks how the voter feels now — he taps **Pleased** (green). The ticket shows a calm confirmation: "Resolved. This is now on record as help delivered." That farmer is now a Green voter in the village's RAG rollup.

Failure: he tries to enter the voter ID while the ticket is still in_progress — the field stays locked and re-shows the helper; the model would reject it anyway (FR-21). No scary error.

### Flow 2 — Dev onboards a rival politician (Platform Console, desktop)

1. Dev, on the ops team, signs in at the unadvertised `/console` route. The world is **steel-skinned** — unmistakably the operator view, no party color anywhere.
2. From **Organizations**, Dev starts **Create organization**: sets the org identity, picks its **constituency** (one Assembly seat — a one-time hard choice), sets the **party affiliation**, creates the first **Org Admin**, and seeds the **Politician roster** (own candidate + two known opponents).
3. Dev finishes; the new org goes live, fully isolated. Its Org Admin will log in at the clean root path and land on an empty, party-themed dashboard.
4. **Climax:** a rival candidate in the *same* Assembly is already on SAC-PAD. Dev opens that rival's **organization detail** for a support check — the **`console-org-banner`** appears and stays: "You're viewing {Rival Org}'s data. This access is logged," and an `ActivityLog` entry is written (FR-17/FR-54). Dev never sees the two orgs' data mixed; each references the same shared Assembly/Village rows but their content is separated by organization. Two rivals, one platform, no leak — and every operator glance into either is on record.

Failure: Dev is an `ops`-tier Admin not assigned to that rival org — the org simply isn't in the list to open (absent, not locked); there is nothing to click.
