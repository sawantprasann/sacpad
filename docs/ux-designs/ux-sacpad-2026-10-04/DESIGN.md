---
name: SAC-PAD
status: draft
created: 2026-10-04
updated: 2026-10-04
description: Political cadre & constituency-management platform. TailAdmin (Tailwind) base; this DESIGN.md specifies the SAC-PAD delta — a per-org party-theming layer, a reserved RAG/sentiment semantic palette, a workflow-status palette, and the two skins (Org vs. Platform Console). Scope of this draft — Platform Console + Kitchen Cabinet ticket flow.
ui_system: TailAdmin (Tailwind CSS admin dashboard template)
sources:
  - ../../prds/prd-sacpad-2026-10-04/prd.md
  - ../../project_brief.md
colors:
  # SAC-PAD brand-layer deltas on top of TailAdmin defaults. Unlisted tokens
  # (surface/background, body text, border, input, muted, etc.) inherit from TailAdmin.
  primary: '#465FFF'          # TailAdmin brand-500 — SAC-PAD default + Platform Console primary
  primary-foreground: '#FFFFFF'
  # --- Per-org party accent (DYNAMIC, set at runtime from Party.color) ---
  party-accent: 'var(--org-party-color)'        # bounded accent only; resolved per organization
  party-accent-foreground: 'var(--org-party-contrast)'  # auto-computed black/white for AA on the accent
  party-accent-fallback: '#465FFF'              # TailAdmin brand-500; used when org has no party (Independent)
  # --- RESERVED semantic palette: RAG / voter sentiment. NEVER overridden by party accent. ---
  rag-green: '#12B76A'        # pleased
  rag-green-foreground: '#FFFFFF'
  rag-amber: '#F79009'        # transit
  rag-amber-foreground: '#1A1208'
  rag-red: '#F04438'          # displeased
  rag-red-foreground: '#FFFFFF'
  # --- Ticket workflow-status palette: deliberately COOL/outlined, kept distinct from RAG ---
  status-open: '#64748B'          # slate — logged, not yet worked
  status-in-progress: '#2970FF'   # indigo-blue — active
  status-closed: '#039855'        # emerald (darker than rag-green) — resolved
  status-blocked: '#B42318'       # dark rose (darker than rag-red) — stuck
  # --- Platform Console operator chrome + consequence signals ---
  console-bar: '#1D2939'      # dark steel top bar — "you are in the operator view"
  console-bar-foreground: '#ECEFF3'
  audit-warn: '#FEF0C7'       # soft amber banner background for logged cross-org access
  audit-warn-foreground: '#7A2E0E'
  audit-warn-border: '#F79009'
typography:
  # Body / label / caption inherit TailAdmin's sans ramp (Outfit/Inter-class). English-only v1.
  # No display-serif moment — this is an operational tool, not an editorial surface.
  numeric:
    fontFeatureSettings: '"tnum" 1'   # tabular figures for tables, counts, ticket numbers, RAG tallies
rounded:
  # Inherit TailAdmin: inputs/buttons rounded-lg (8px), cards rounded-2xl (16px).
  pill: 9999px                 # status pills, RAG chips, sentiment segments
spacing:
  # TailAdmin / Tailwind 4-based scale inherited as-is.
  touch-min: 44px              # minimum touch target on the mobile ticket flow
components:
  status-pill:
    shape: '{rounded.pill}'
    treatment: 'subtle tinted background + colored dot + label; NOT a solid fill'
    open: { color: '{colors.status-open}' }
    in-progress: { color: '{colors.status-in-progress}' }
    closed: { color: '{colors.status-closed}' }
    blocked: { color: '{colors.status-blocked}' }
  rag-chip:
    shape: '{rounded.pill}'
    treatment: 'SOLID fill — distinct from the subtle status pill'
    green: { background: '{colors.rag-green}', foreground: '{colors.rag-green-foreground}' }
    amber: { background: '{colors.rag-amber}', foreground: '{colors.rag-amber-foreground}' }
    red: { background: '{colors.rag-red}', foreground: '{colors.rag-red-foreground}' }
  new-ticket-fab:
    surface: 'mobile ticket flow only'
    background: '{colors.party-accent}'
    foreground: '{colors.party-accent-foreground}'
    position: 'bottom-right, thumb-reachable, floats above the category list and table'
    min-size: '{spacing.touch-min}'
  ticket-card:
    surface: 'mobile list (replaces the desktop center table row)'
    radius: '{rounded.pill}'  # card itself uses TailAdmin card radius; status via status-pill
    shows: 'ticket_number, person + village, category icon, status-pill, reported date'
  voter-gate-field:
    state-locked: 'disabled input + lock glyph + helper text; visible but non-editable until status=closed'
    state-unlocked: 'enabled on closure; party-accent focus ring'
  sentiment-picker:
    type: 'segmented control, 3 segments'
    segments: ['pleased → {colors.rag-green}', 'transit → {colors.rag-amber}', 'displeased → {colors.rag-red}']
  console-org-banner:
    background: '{colors.audit-warn}'
    foreground: '{colors.audit-warn-foreground}'
    border: '{colors.audit-warn-border}'
    copy-ref: 'EXPERIENCE.md Voice and Tone'
  module-toolbar:
    inherits: 'TailAdmin button group'
    actions: ['Export Excel', 'Prepare Chart', 'Bar/Pie/Line toggle', 'Export Chart', 'Get All Details']
---

## Brand & Style

SAC-PAD is an operational system of record for a political campaign — grievances, cadre work, field intel, and voter sentiment. It is not a consumer app and not an editorial surface; it should read as a **trustworthy instrument**: dense where the operator needs density, calm and glanceable where the field user needs speed, and unmistakably **sober in the operator's room**. Restraint is the posture. The one place emotion is allowed is the ticket-resolution moment (attaching a voter and marking them *pleased*) — that beat earns a small, satisfying confirmation, nothing more.

SAC-PAD inherits **TailAdmin** (Tailwind admin template) wholesale. This DESIGN.md specifies only the SAC-PAD-specific layer:

1. a **per-organization party-theming** accent (each campaign's UI picks up its party color + logo), bounded so it can never break the UI or hijack meaning;
2. a **reserved semantic palette** for RAG / voter sentiment that party themes may never override;
3. a **cool, distinct workflow-status palette** for ticket states, kept visually separate from RAG;
4. two **skins** — the party-themed **Org skin** and the neutral steel **Platform Console skin** — so an operator always knows which room they're standing in.

TailAdmin's components (tables, forms, buttons, dropdowns, modals, sidebar, cards) ship as-is unless listed in `## Components`.

## Colors

Three color systems coexist, and keeping them from bleeding into each other is the core color discipline.

- **Party accent (dynamic, per org).** On the Org side, `{colors.party-accent}` is resolved at runtime from the organization's Party color (brief §3.1b). It is an **accent only** — primary buttons, active nav, links, the mobile FAB, focus rings, and the exportable chart palette's lead color. It is **never** a full-surface background, never applied to the Platform Console, and `{colors.party-accent-foreground}` is auto-computed (black or white) to hold AA contrast against whatever hue the party supplies. Independent orgs (no party) fall back to `{colors.party-accent-fallback}`. `[ASSUMPTION: party colors arrive as a single hex on Party.color; if a party needs a full palette we revisit.]`
- **RAG / sentiment (reserved, fixed meaning).** `{colors.rag-green}` = pleased, `{colors.rag-amber}` = transit, `{colors.rag-red}` = displeased (PRD FR-43; also the RAG risk mapping FR-45). These three hexes are **semantic constants**. No party accent, no theme, and no module may repurpose them. They render as **solid** `rag-chip` fills so they read as "data," not "chrome."
- **Workflow status (cool, distinct).** Ticket states use `{colors.status-open}` / `status-in-progress` / `status-closed` / `status-blocked`, rendered as **subtle tinted pills with a colored dot** — deliberately *not* solid, so a glance never confuses a ticket's workflow state with a voter's sentiment. `closed` and `blocked` sit darker and cooler than `rag-green`/`rag-red` on purpose.
- **Console chrome.** The Platform Console wears `{colors.console-bar}` dark steel on its top bar and nav, and surfaces `{colors.audit-warn}` on the cross-org access banner. This is the visual signal "you are the operator, and this access is logged" (PRD §8.1, FR-17).
- **Everything else** inherits TailAdmin.

Avoid: tinting surfaces with the party color; letting a party supply a green/amber/red that collides with RAG (clamp or shift such hues and warn); using RAG colors for anything other than sentiment/risk.

## Typography

Inherit TailAdmin's sans ramp. English-only v1, so the type scale is tuned for Latin text `[ASSUMPTION: no Devanagari/RTL sizing constraints in v1]`. One SAC-PAD addition: a `{typography.numeric}` tabular-figures treatment for everything that lines up in columns or counts — ticket numbers, table figures, RAG tallies, login counts, bulk-send progress. No display/serif role; this product doesn't have a hero-headline moment.

## Layout & Spacing

TailAdmin's spacing scale inherited as-is. Two SAC-PAD rules:

- **Org side is responsive, ticket flow is mobile-first.** The Kitchen Cabinet capture/work flow is designed at `sm` first and scales up; the desktop view is the same flow widened into TailAdmin's sidebar + center-table shell. All interactive targets respect `{spacing.touch-min}` (44px) on touch.
- **Platform Console is desktop-primary**, denser, built on TailAdmin's standard sidebar + content layout. It is not optimized for phones in v1 (`[NON-GOAL for MVP]`).

Shared chrome (both skins, per brief §5): top bar (app name, user photo/name, session timestamp, login count, settings), module toolbar, left category/entity sidebar, center table or report panel.

## Elevation & Depth

Inherit TailAdmin. Elevation is not a hierarchy device here except for two floating elements: the mobile `new-ticket-fab` and the mobile category/sentiment bottom-sheets. Modals stack at most one level deep.

## Shapes

Inherit TailAdmin radii (inputs/buttons 8px, cards 16px). Status pills, RAG chips, and sentiment segments are fully rounded (`{rounded.pill}`). The visual contract: **pills = status/sentiment, rectangles = data and actions.**

## Components

Inherited from TailAdmin unchanged: data table, form inputs, select/dropdown, modal/dialog, sidebar nav, cards, tabs, avatar, toast, pagination.

SAC-PAD-specific (see frontmatter tokens for visual specs; behavioral rules in EXPERIENCE.md):

- **status-pill** — ticket workflow state. Subtle tint + dot, never solid.
- **rag-chip** — voter sentiment / RAG cell. Solid fill, reserved palette.
- **new-ticket-fab** — mobile-only floating "log a ticket," party-accented, thumb-reachable.
- **ticket-card** — mobile list item replacing the desktop table row.
- **voter-gate-field** — the `voter_id` input: visibly present but locked until the ticket is closed.
- **sentiment-picker** — 3-segment pleased/transit/displeased control shown at closure.
- **console-org-banner** — the logged-access banner shown whenever an Admin views a specific org's data.
- **module-toolbar** — the shared Export/Chart/Get-All-Details button group.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Use the party accent for accents only (buttons, nav, links, FAB, chart lead color) | Tint whole surfaces or the Console with a party color |
| Keep `rag-green/amber/red` exclusively for sentiment/risk, always solid chips | Reuse RAG colors for ticket workflow status or decoration |
| Render ticket status as subtle cool pills with a dot | Let `closed`/`blocked` read as `rag-green`/`rag-red` |
| Auto-compute accent foreground for AA; clamp party greens/reds that collide with RAG | Trust an arbitrary party hex to be contrast-safe |
| Wear the steel Console skin + audit banner in the operator view | Make the Console look like a campaign dashboard |
| Mobile-first ticket capture, 44px targets, FAB | Force the field user through a desktop table on a phone |
