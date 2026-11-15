# Assistant chat — development plan

Status: draft
Date: 2026-11-15

A signed-in user types a question about their own organization. Rails answers from the database the menus already use. A local Ollama model only decides which lookup to run, and later writes a speech from a briefing Rails has already built.

## Decisions

- The model runs on a separate Ubuntu server with Ollama. It has no database login and no route to the public internet.
- Rails is the only thing that queries Postgres. Every query stays inside `acts_as_tenant`, the user's organization constituency, and `Role#can_access?`.
- Factual answers are rendered by Rails, in the user's current locale (English or Marathi). The model is not allowed to restate a count, a name, or a phone number.
- The speech is the only prose the model writes. It is labeled as a draft and uses only the briefing packet.
- Voter answers in chat are a count plus up to 20 names, with a link to the existing filtered page. Mobile numbers are not sent to the model and are not printed in the chat. Sarpanch and karyakarta answers include the phone already shown on the ground-report page.
- A speech may use stored election results, including margins and party names already on the election-result page. It leaves out any section the briefing marks empty.
- Ollama cloud models stay off.

## What the first release answers

| User question | Tool | Module permission | Source |
|---|---|---|---|
| Beneficiaries of a village, taluka, or booth | `count_beneficiaries` | `kitchen_cabinet` | `KitchenCabinet::Ticket` |
| Displeased (or pleased, transit) voters of a village, taluka, or booth | `list_voters` | `voter_lists` | `VoterSentiment` joined to `Voter` |
| How many local karyakartas in this village | `count_karyakartas` | `ground_reports` | `GroundReports::VillageLocalKaryakarta` |
| Name and number of the sarpanch of a village | `local_admin_contact` | `ground_reports` | `GroundReports::VillageLocalAdminContact` |
| Write a speech for a village | `draft_speech` | every section gated by its own module | Briefing from the four tools above, plus ground reports, cadre notes, and `ConstituencyElection` |

A user missing a module never receives that tool. The model cannot ask for it.

Later tools, not in this release: PR records, booth checklists, social pages, calendar, team.

## Known data gaps

These are accepted for the first release. The answer text says how the number was matched.

- Beneficiary tickets store `village` as plain text, with no taluka or booth column. A village count matches that text to `Village#name` and `Village#native_name` inside the organization. A taluka count is the sum of those village matches. A booth count uses tickets linked to a voter in that booth. Tickets with no voter link are excluded from the booth number, and the reply says so.
- Cadre activities have no `village_id`. Location is free text on some category details. The speech includes a cadre section only when that text matches the village name. Otherwise the section is omitted.
- Sarpanch is not an enum. Match `role_title` against `sarpanch` and `सरपंच`. If several rows match, list them. If none match, say there is no sarpanch on the village record.

## Runtime

```
Browser  →  Rails (session, policy, SQL)  →  private HTTP  →  Ollama
                 ↑
              Postgres
```

- Dev and production set `OLLAMA_URL` (for example `http://10.0.0.12:11434`). No API key in the app. The network itself is the boundary.
- Development model: `qwen3:8b`. Speech quality is judged on that model before any larger download.
- One model loaded. Parallel chats: `OLLAMA_NUM_PARALLEL=2` in development, `4` on a GPU server that still has free memory after loading the model. Context length `8192`.
- Request timeout 30 seconds for a lookup, 90 seconds for a speech. A timeout becomes "I could not answer that just now."
- Rails keeps the last resolved place on the conversation, so "the sarpanch" after a Paranda question still means Paranda.

## Build order

### 1. Ollama client

A service object posts to Ollama's chat API with a tool list and reads back a single tool call. It rejects any response that is not one of the offered tools, or whose arguments fail validation. Unit tests use a stubbed HTTP response. No chat page yet.

Config lives in the environment: `OLLAMA_URL`, `OLLAMA_MODEL`. Missing URL in development skips the live call and returns a clear error.

### 2. Chat page

`Assistant::Conversation` and `Assistant::Message`, both `OrganizationScoped`, owned by `current_user`. One page, linked from the sidebar for any signed-in user who can open at least one of the four modules. The form posts the question. The reply is rendered into the thread with Turbo. Messages store the question, the tool name, the tool arguments, and the Rails-rendered answer. They do not store a raw model essay for factual replies.

Empty state shows the five example questions. The page works in English and Marathi through the existing locale files.

### 3. Place resolution

A place finder searches villages, talukas, and booths visible to the organization. It compares the typed name with `name` and `native_name`, case-insensitive, trimmed. One match is used. Several matches make the chat ask which place, and the next message is the choice. No match says the place is not in this constituency. "This village" with no earlier place asks for the name.

### 4. Four lookup tools

Each tool is a Ruby object with a name, a JSON argument schema, a permission, and a `call` method. The router sends the model only the tools the current role can access.

- `count_beneficiaries` returns the count, the match method (`village_text` or `voter_booth`), and the existing beneficiaries path with the filter that can be applied today.
- `list_voters` filters `VoterSentiment` by status and by village, taluka, or booth. Returns the count and at most 20 full names. The answer links to the voter list for that place.
- `count_karyakartas` returns the count and the names. Phone is included because the question asks for local contacts the user can already open.
- `local_admin_contact` returns matching name, role title, and phone.

Every successful tool call writes an `ActivityLog` row: actor, action `assistant.query`, organization, tool name, place id, and result count. The log does not store the question text if that text contains a voter name the user typed, but it does store the tool and the place.

Rails renders the answer with I18n. A tool the role cannot access is not called, even if the model names it.

### 5. Speech

`draft_speech` builds a briefing hash for one village:

- beneficiary count, with the match caveat
- karyakarta count and sarpanch name and phone, when Ground Reports is allowed
- latest ground-report issue and resolution texts, truncated
- cadre notes whose location text matches the village, when Cadre Program is allowed
- latest constituency election year, winner, and margin, when the election result is visible to this user

The model receives that hash and a short instruction: write a speech for a visit today, use only these facts, skip empty sections, reply in the user's locale. The stored message is marked `draft`. The page shows "Draft for your speech" above the text.

### 6. Safety checks before anyone relies on it

- Organization A, asking about a village that also exists for organization B, receives only A's tickets, sentiments, contacts, and reports.
- A role with no `voter_lists` access gets no voter names, and the voter tool is absent from the tool list.
- A role with no `ground_reports` access gets no phone numbers.
- An ambiguous village name does not guess.
- A model response that invents a tool, or adds arguments, is discarded.
- Ten scripted questions, five English and five Marathi, run against a fixture organization in the test suite with the HTTP client stubbed. A separate manual pass runs the same ten against a live Ollama once the server exists.

## Out of scope

- Letting the model write SQL or hold a database password.
- Sending voter mobiles or the full roll to Ollama.
- Creating or editing tickets, sentiments, contacts, or reports from the chat.
- Console (Admin) access to the chat.
- PR, social, booth checklist, and calendar questions.
- Replacing Ollama with a hosted model.

## Done when

A user who can open Beneficiaries, Voter Lists, and Ground Reports can ask, in English or Marathi, for a beneficiary count, a displeased-voter list, a karyakarta count, and a sarpanch name and number for a village in their constituency, and each answer matches the same filters on the existing pages. The speech draft mentions only facts present in the briefing. A second organization cannot see those answers.
