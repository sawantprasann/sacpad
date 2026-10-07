---
story_key: 0-16-org-admin-dashboard
epic: 0
depends_on: 0-14-shared-chrome-export-dashboard
baseline_commit: 597d5ae
---

# Story 0.16: Org admin dashboard — Kitchen Cabinet & Cadre oversight

Status: ready-for-dev

## Story

As an organization admin,
I want to see and manage all Kitchen Cabinet tickets and Cadre Program activities for my organization,
So that I can oversee grievance resolution and field organizing activities across my entire team.

## Acceptance Criteria

1. Given an org admin on the organization details page, when I navigate to the new **Kitchen Cabinet** tab/section, then I see all tickets for my org grouped by category with view/edit/delete capabilities, scoped to org (not subtree).
2. When I view the tickets, I can filter by category, status, and search by person name/details — counts use tabular figures (UX-DR6).
3. Given an org admin on the same page, when I navigate to the **Cadre Program** tab/section, then I see all cadre activities for my org with view/create/edit/delete capabilities (org-scoped, not subtree-scoped).
4. Both sections respect the org admin's role permissions (Console::Organizer or above) and show read-only views for lower-permission admins.

## Tasks / Subtasks

- [ ] Task 1: Extend org details page to add KC + Cadre tabs (AC: 1, 3)
  - [ ] On `app/views/console/organizations/show.html.erb`, add two new tabs: **Kitchen Cabinet** and **Cadre Program** (alongside existing sections).
  - [ ] Tabs are only visible to org admins (role check: `can_create_users?`).
  - [ ] The tabs use a shared tab-navigation component (or simple anchor links + sections if simpler).
- [ ] Task 2: Kitchen Cabinet section — org-scoped ticket list with filters (AC: 1, 2)
  - [ ] Create a new `OrgTicketOverviewController` action or extend `console/tickets_controller.rb` with an `index` action that:
    - Returns ALL tickets for the org (no subtree filter — this is org admin oversight, not personal view).
    - Scoped via org (acts_as_tenant), not via policy_scope subtree.
    - Supports filters: `?category=`, `?status=`, `?q=` (search person_name/village/mobile).
    - Paginated (pagy, same as KC list).
  - [ ] View: `app/views/console/org_tickets/index.html.erb` (or console/organizations/_tickets_section.html.erb partial):
    - Desktop: table with columns — Ticket#, Person, Category, Status, Owner, Reported date, Actions (view/edit/delete).
    - Mobile: card list via `_ticket_card` partial (reuse from KC).
    - Filters: category select, status select, text search input.
    - Counts use `tabular-nums` (UX-DR6).
    - Show filtered count vs. total count.
  - [ ] Authorization: org admins only; lower admins get read-only.
  - [ ] Links: clicking a ticket row opens the ticket detail in a modal/overlay or full page (decision below).
- [ ] Task 3: Cadre Program section — org-scoped cadre activity list (AC: 3)
  - [ ] Create a similar index for cadre activities (scoped to org, not subtree).
  - [ ] Route: nested or parallel to tickets (TBD with user).
  - [ ] View: list of all cadre activities (format TBD once Story 2.1 is clearer on the data shape).
  - [ ] Filters: by category (from cadre story), date range, created-by user.
  - [ ] Actions: view detail, create new, edit, delete (org admin only).
- [ ] Task 4: Authorization & read-only fallback (AC: 4)
  - [ ] Org admins (Console::Organizer `can_create_users?`) get full CRUD.
  - [ ] Lower console admins (no user-creation permission) see read-only views (no edit/delete buttons).
  - [ ] Enforce via Pundit policy: `Console::OrgTicketPolicy` and `Console::CadreActivityPolicy`.
- [ ] Task 5: Tests + verify (AC: all)
  - [ ] Integration test: org admin logs in, navigates to org details, sees KC + Cadre tabs, can search/filter/view/edit tickets.
  - [ ] Test: read-only admin sees view-only layout (no edit/delete buttons).
  - [ ] Test: tickets/activities are org-scoped (another org's data is NOT visible).
  - [ ] Test: tenants properly isolated.
  - [ ] `bin/rails test` + `bin/rubocop` green.

## Dev Notes

- **Scope boundary:** This is a console/admin-side feature that gives org-level oversight into Kitchen Cabinet (Epic 1) and Cadre Program (Epic 2) data. Unlike the module-specific views (which are subtree-scoped for team leads), the admin dashboard shows org-wide data.
- **Org-scoped, not subtree-scoped:** The tickets and cadre activities shown are for the entire org, not filtered by the admin's personal subtree. The admin is viewing as an overseer, not as a team member.
- **Reuse patterns from KC/Cadre:** Reuse the ticket card/table components from the KC list, reuse the category/status filter patterns, reuse the pagy pagination. The goal is consistency, not reinvention.
- **Authorization:** Use `can_create_users?` as the gate for full admin capability (org admins can CRUD; lower admins see read-only).
- **Modal vs. full page for detail:** TBD with user — should clicking a ticket open a modal/overlay or navigate to a new full page?
- **Cadre data shape TBD:** Story 2.1 defines the cadre activity structure; this story assumes it exists and just wraps it in an admin view. The Cadre section can be a placeholder if 2.1 isn't implemented yet.
- **Files being changed:**
  - `app/views/console/organizations/show.html.erb` — add tabs/sections.
  - `app/controllers/console/tickets_controller.rb` or new `console/org_tickets_controller.rb` — add org-wide index.
  - `app/views/console/org_tickets/` or `_tickets_section.html.erb` — new views for the tabs.
  - `app/policies/console/org_ticket_policy.rb` (new) — authorization.
  - Similar for cadre.

## References

- [Source: docs/architecture.md] — console admins, org-scoping via acts_as_tenant, multi-tier admin roles.
- [Source: docs/stories/1-3-browse-open-tickets.md] — ticket list + filter patterns to reuse.
- [Source: app/views/console/organizations/show.html.erb] — where the tabs will be added.

## Dev Agent Record

### Agent Model Used

(to be filled by dev agent)

### Debug Log References

### Completion Notes List

### File List

## Change Log

| Date | Change |
|------|--------|
| 2026-10-07 | Story 0.16 drafted (manual) — org admin dashboard extending org details page with Kitchen Cabinet + Cadre Program oversight (org-scoped, not subtree; CRUD for admins, read-only for lower tiers). Tabs added to org details; reuse KC/Cadre list patterns. Status → ready-for-dev. |

## Status

ready-for-dev
