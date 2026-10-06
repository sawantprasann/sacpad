---
story_key: 0-15-voter-primitive
epic: 0
depends_on: 0-14-shared-chrome-export-dashboard
baseline_commit: 183effd82bb6747ae6d6ff3bc94e8ac31c210940
---

# Story 0.15: Voter primitive for cross-module sentiment

## Story

As a developer,
I want the org-scoped `Voter` table with sentiment columns and Tier-1 versioning,
So that Kitchen Cabinet (Epic 1) can record voter sentiment without depending on the Voter Lists module (Epic 6).

## Acceptance Criteria

1. Given the foundation and audit framework, when the Voter primitive is created, then a `voters` table exists, org-scoped (`organization_id` required), carrying PII fields and `sentiment_status` (pleased/transit/displeased, nullable, mutable), `sentiment_updated_by_id`, `sentiment_updated_at` (FR42, FR43).
2. `Voter` has a Tier-1 `VoterVersion` custom version class so sentiment/PII history is captured (FR52).
3. PII fields are encrypted at rest via Active Record Encryption (NFR18).
4. The per-model isolation test from Story 0.2 passes for `Voter`.
5. The Voter Lists *experience* (import, filtered lookup, access controls) is explicitly out of scope here and lands in Epic 6.

## Tasks/Subtasks

- [x] Task 1: Voters table + migration (AC: 1)
  - [x] `voters`: org-scoped (`organization_id` required), PII fields, `sentiment_status` enum (pleased/transit/displeased, nullable, mutable), `sentiment_updated_by_id`, `sentiment_updated_at`
- [x] Task 2: Tier-1 version class (AC: 2)
  - [x] `VoterVersion` custom version class (via the Story 0.10 Tier-1 pattern) capturing sentiment/PII history
- [x] Task 3: PII encryption (AC: 3)
  - [x] Active Record Encryption on PII fields; encryption keys configured in development/test environments
- [x] Task 4: Tests + verify (AC: 4)
  - [x] Per-model isolation test from Story 0.2 passes for `Voter`; sentiment + versioning + encryption tests

## Dev Notes

- **Context:** architecture §Voter primitive + §Audit (Tier-1). Brief FR42/FR43/FR52, NFR18.
- **Scope guard:** ONLY the org-scoped `Voter` primitive (columns, sentiment, Tier-1 versioning, PII encryption) so Epic 1 can record sentiment. The Voter Lists *experience* — bulk import, filtered lookup, PII access controls — is explicitly Epic 6.
- **Tenancy:** `Voter` is tenant-scoped (`organization_id` required) and must pass the Story 0.2 per-model isolation test; PII is encrypted at rest.

## Dev Agent Record

### Debug Log

- `sentiment_status` is a nullable, mutable enum (pleased/transit/displeased) with `sentiment_updated_by_id`/`sentiment_updated_at`, so Kitchen Cabinet can record sentiment without the full Voter Lists module.
- A dedicated `create_versions` migration + `VoterVersion` establish the Tier-1 custom version class; Active Record Encryption keys were added to development/test environments so PII encrypts at rest in those environments.

### Implementation Plan

`create_voters_and_versions` + `create_versions` migrations → `Voter` (org-scoped, sentiment enum, AR Encryption on PII) + `VoterVersion` custom version class → configure AR Encryption in dev/test environments → voter isolation + sentiment + versioning tests.

### Completion Notes

- The org-scoped `voters` table carries encrypted PII and a nullable/mutable `sentiment_status` (+ updated-by/at), with a Tier-1 `VoterVersion` class capturing history.
- PII is encrypted at rest via Active Record Encryption; the Story 0.2 per-model isolation test passes for `Voter`. The Voter Lists experience remains Epic 6.

## File List

- `app/models/voter.rb` (added — org-scoped, sentiment, AR Encryption)
- `app/models/voter_version.rb` (added — Tier-1 custom version class)
- `config/environments/development.rb`, `config/environments/test.rb` (modified — AR Encryption keys)
- `db/migrate/20261004140900_create_voters_and_versions.rb`, `db/migrate/20261004151012_create_versions.rb` (added)
- `db/schema.rb` (modified)
- `test/models/voter_test.rb` (added)

## Change Log

| Date | Change |
|------|--------|
| 2026-10-04 | Story 0.15 **backfilled from commit 8484d1e** — org-scoped `Voter` primitive with encrypted PII, nullable/mutable `sentiment_status`, and a Tier-1 `VoterVersion` class; Voter Lists experience deferred to Epic 6. Status → review. |

## Status

review
