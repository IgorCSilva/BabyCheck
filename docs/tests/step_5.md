# Manual Test Plan — Step 5: Breastfeeding Log

Scope: [roadmap.md](../base_content/roadmap.md) Step 5 — logging a breastfeeding session
with one tap, editing/deleting entries after the fact, and a dedicated page that lists
entries by day and totals them over a selected date range. This step is explicitly
"identical structure to Step 3" ([step_3.md](step_3.md)), just with no `peed`/`pooped`
flags (a breastfeeding session is a bare timestamped event) and the blush breastfeeding
accent (`#E8899E`) in place of diaper sand. Every test below assumes a logged-in account
with at least one baby already exists.

One design point worth keeping in mind while testing: **the one-tap button never asks for
anything up front.** The timestamp defaults to "now," entirely server-side — any
correction (wrong time) is an *edit after the fact*, never a required step before the tap
is accepted. Several tests below check that this default lives on the API, not just in
the form.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- Mailpit isn't needed for this step — nothing here sends email.
- **Start from an empty database.** This file assumes zero users, babies, and breastfeeding
  logs before Test 1. If you're re-running this file, empty it first with the snippet
  below (the same one this file's [Cleanup](#cleanup) section ends with).
- All DB verification below uses `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.BreastfeedingLogs.BreastfeedingLog
  import Ecto.Query
  ```
- A few tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering (no bearer token, another account's log id, a malformed
  field value). Get a token the same way the UI does:
  ```
  curl -s -X POST http://localhost:4000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"<email>","password":"<password>"}'
  ```
  The response body's `data.access_token` is your bearer token.

### Resetting the database to empty

Truncates every application table (everything except `schema_migrations`) without
dropping/recreating the database or restarting any container:

```
docker compose exec api iex -S mix
```
```elixir
alias Api.Repo

{:ok, %{rows: rows}} =
  Ecto.Adapters.SQL.query(Repo, "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename != 'schema_migrations'")

tables = List.flatten(rows)
Ecto.Adapters.SQL.query!(Repo, "TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE")
```

### Creating the account and baby these tests share

Most tests below continue from one signed-up account with one baby. Create it once, via
the UI:

1. Open `http://localhost:3000/signup`.
2. Email `parent@example.com`, Password `supersecret123`, Confirm password
   `supersecret123`. Submit.
3. On the `/babies` page you land on, add Name `Riley`, pick the first swatch (soft pink).
   Submit.
4. Go to `http://localhost:3000/`. Click "Go to breastfeeding."

**Expected result:** you land on `/breastfeeding` with a header reading "0 breastfeeding
sessions," a row of range tabs (Today / 7 days / 30 days / Custom) with "Today" active
filled in the blush breastfeeding accent, a "Log breastfeeding" button in the same blush
color, and an empty-state message — this starting point is what Test 1 checks explicitly.

---

## Positive cases

### Test 1 — The breastfeeding log page starts empty for a brand new baby

**Setup:** continue right after the setup above.

**Steps (UI)**
1. Look at the range header and the list area below the quick-log button.

**Expected UI result**
- The big number reads `0`.
- Below the quick-log button: "No breastfeeding sessions in this range yet."

**Backend verification**
```elixir
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 0
```
**Pass criteria:** zero breastfeeding logs in the database, matching the empty UI.

---

### Test 2 — One tap logs a breastfeeding session with a sensible default timestamp

**Setup:** continue from Test 1, still on `/breastfeeding`.

**Steps (UI)**
1. Click "Log breastfeeding."

**Expected UI result**
- Immediately: a dark toast appears at the bottom reading "Breastfeeding logged" with an
  "Undo" link, and the button's Nightlight Glow pulses once in the baby's theme color
  (soft pink).
- A new row appears under a "Today" day header showing the current time.
- The range total updates to `1`.
- The toast disappears on its own after a few seconds if left alone.

**Backend verification**
```elixir
log = Repo.one(from b in BreastfeedingLog)
log.baby_id   # => Riley's id
log.logged_at # => within the last few seconds
```
**Pass criteria:** the tap required no form and no fields, yet produced a fully-formed,
persisted record — exactly the "one tap, nothing required first" guarantee the design
calls for.

---

### Test 3 — A second entry stacks under the same day header and the total updates

**Setup:** continue from Test 2.

**Steps (UI)**
1. Click "Log breastfeeding" again.

**Expected UI result**
- Two rows now show under the single "Today" header, newest on top.
- The range total reads `2`.

**Backend verification**
```elixir
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 2
```
**Pass criteria:** entries for the same day group together under one header instead of
duplicating headers, and the total reflects every entry in the range, not just the latest.

---

### Test 4 — Editing an entry's timestamp updates it in place, not as a new row

**Setup:** continue from Test 3 (two entries today).

**Steps (UI)**
1. Wait for the first row's "Edit"/"Delete" links to become enabled (they're disabled
   while that row is still the optimistic placeholder from Test 3's tap).
2. Click "Edit" on that row.
3. Change the date field back one day (keep the time) and click "Save."

**Expected UI result**
- While editing, the row becomes an inline form with just a datetime field (no checkboxes
  — a breastfeeding session has no flags to toggle).
- After saving, the entries now span two day headers — "Today" (one row) and "Yesterday"
  (the edited row) — and the row count stays at 2 overall; no third row appears.
- The range total (still "Today," unaffected by the edited-out row) reads `1`.

**Backend verification**
```elixir
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 2 (still two rows — this was an update, not an extra insert)
```
**Pass criteria:** the same row was updated; editing is how a tap's timestamp gets
corrected, exactly as the roadmap's "edit after the fact" design intends.

---

### Test 5 — Switching the range preset changes which entries count

**Setup:** continue from Test 4 (one entry today, one backdated to yesterday).

**Steps (UI)**
1. Click the "7 days" tab. Confirm the total reads `2` (both entries fall in range).
2. Click "Today" again.

**Expected UI result**
- "7 days" shows `2`.
- "Today" shows `1` — only the entry that wasn't backdated.

**Pass criteria:** the displayed total is always a live `COUNT` over whatever range is
selected, not a cached or stored running total — narrowing or widening the range changes
it without losing any underlying data.

---

## Negative cases

### Test 6 — Undo removes the entry, even if clicked before the request finishes

**Setup:** continue from Test 5 (on `/breastfeeding`, "Today" selected, total `1`).

**Steps (UI)**
1. Click "Log breastfeeding" again.
2. As soon as the toast appears, click "Undo" immediately.

**Expected UI result**
- The row briefly appears (the optimistic insert), then disappears once "Undo" is
  clicked.
- The range total returns to `1` — back to where it was before this tap.

**Backend verification**
```elixir
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 2 (the undone entry never persists, or is deleted right after it does; the
#       yesterday entry from Test 4 is still there too)
```
**Pass criteria:** "Undo" reliably removes the optimistic entry both from the screen and
from the database, regardless of whether the create request had already completed when
the click happened.

---

### Test 7 — An invalid field value is rejected by the API

The UI can never actually send a blank timestamp (the `datetime-local` input requires a
value), so this is checked directly against the API. Using the remaining log id:

**Steps**
```
curl -s -X PUT http://localhost:4000/api/breastfeeding_logs/<log_id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"logged_at":""}'
```

**Expected result**
- `422` with `{"errors":{"logged_at":["can't be blank"]}}`.

**Pass criteria:** the API validates required fields server-side, independent of whatever
the UI's own inputs happen to restrict a user to.

---

### Test 8 — One account can't view, edit, or delete another account's breastfeeding logs

**Setup**
1. Sign up a second account (in a private/incognito window, so it doesn't disturb session
   A): `parent2@example.com` / `supersecret123`, add a baby named `Other`, and log one
   breastfeeding session for it.
2. Note `Other`'s baby id and that log's id from session B's own `/api/babies` and
   `/api/babies/<other_baby_id>/breastfeeding_logs` responses.

**Steps**
```
# Using parent@example.com's token against parent2's baby/log ids:
curl -s -i http://localhost:4000/api/babies/<other_baby_id>/breastfeeding_logs \
  -H "Authorization: Bearer <parent_token>"

curl -s -i -X PUT http://localhost:4000/api/breastfeeding_logs/<other_log_id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <parent_token>" \
  -d '{"logged_at":"2026-11-22T00:00:00Z"}'

curl -s -i -X DELETE http://localhost:4000/api/breastfeeding_logs/<other_log_id> \
  -H "Authorization: Bearer <parent_token>"
```

**Expected result**
- All three calls return `404` with `{"errors":{"detail":"not found","code":"not_found"}}`
  — not a `403`, so the response doesn't even confirm a log with that id exists.

**Backend verification**
```elixir
log = Repo.one(from b in BreastfeedingLog, where: b.baby_id == ^other_baby_id)
log.logged_at  # => unchanged from the original value
Repo.aggregate(from(b in BreastfeedingLog, where: b.baby_id == ^other_baby_id), :count)
# => 1 (the DELETE never ran)
```
**Pass criteria:** every breastfeeding-log lookup is scoped by the authenticated user's own
baby ownership server-side — a log id or baby id alone is never enough to read or change
it.

---

## Validation / edge cases

### Test 9 — Deleting an entry removes it everywhere

**Setup:** continue session A from Test 6 (two entries exist: today's and yesterday's).

**Steps (UI)**
1. Click the "7 days" tab so both rows are visible.
2. Click "Delete" on either row and confirm the browser prompt.

**Expected UI result**
- The row disappears immediately, the total drops to `1`.

**Backend verification**
```elixir
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 1
```
**Pass criteria:** the delete persists server-side, not just visually.

---

### Test 10 — A non-numeric log id is rejected as "not found," not a server error

**Steps**
```
curl -s -i -X PUT http://localhost:4000/api/breastfeeding_logs/not-a-number \
  -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-22T00:00:00Z"}'

curl -s -i -X DELETE http://localhost:4000/api/breastfeeding_logs/not-a-number \
  -H "Authorization: Bearer <token>"
```

**Expected result**
- Both return `404` with `{"errors":{"detail":"not found","code":"not_found"}}` — not a
  `500`.

**Pass criteria:** a malformed id is handled gracefully instead of crashing the request
(the kind of input a careless script or a tampered URL might send).

---

## Security / session cases

### Test 11 — Every breastfeeding-log endpoint requires authentication

**Steps**
```
curl -s -i http://localhost:4000/api/babies/1/breastfeeding_logs
curl -s -i -X POST http://localhost:4000/api/babies/1/breastfeeding_logs
curl -s -i -X PUT http://localhost:4000/api/breastfeeding_logs/1 -d '{"logged_at":"2026-11-22T00:00:00Z"}'
curl -s -i -X DELETE http://localhost:4000/api/breastfeeding_logs/1
```

**Expected result**
- All four return `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`.

**Pass criteria:** the API enforces authentication on every breastfeeding-log action on its
own — this isn't only a frontend-side gate.

---

### Test 12 — Omitting the body on create still produces a fully-defaulted log

This is the API-level proof behind Test 2's UI behavior: the "one tap, nothing required"
guarantee is owned by the server, not just by the fact that the button happens to send no
fields.

**Steps**
```
curl -s -X POST http://localhost:4000/api/babies/<baby_id>/breastfeeding_logs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{}'
```

**Expected result**
- `201` with a body like
  `{"data":{"id":<id>,"baby_id":<baby_id>,"logged_at":"<now, ISO 8601>"}}`.

**Pass criteria:** a request with a completely empty body is accepted and defaulted —
confirming a client bug that forgets to send a field could never block a one-tap log from
succeeding.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Fresh baby, no logs | `0` total; empty-state message |
| 2 | One-tap log | Toast + glow pulse; row with the current time; total `1`, fully defaulted server-side |
| 3 | Second one-tap log | Stacks under the same day header; total `2` |
| 4 | Edit an entry's timestamp | Updates in place; row count unchanged; can move an entry to a different day group |
| 5 | Switch range preset | Total reflects only the selected window |
| 6 | Undo | Entry removed from screen and DB, even if clicked early |
| 7 | Invalid field value | Rejected, `422` |
| 8 | View/edit/delete another account's logs | `404` every time, ownership enforced server-side |
| 9 | Delete an entry | Removed from list, total, and DB |
| 10 | Non-numeric id | `404 not_found`, not a crash |
| 11 | Breastfeeding-log endpoints with no token | `401 unauthenticated` on every verb |
| 12 | Create with an empty body | `201`, fully defaulted (`logged_at` now) |

If every row holds, Step 5 closes out Phase 2: all three of the spec's tracked activities
(diaper, bottle, breastfeeding) are fully loggable, each following the exact same
ownership, one-tap-default, and live-range-total guarantees — a solid foundation for
Phase 3's global feed and charts to aggregate across.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so Step 6's tests can
start from the same clean slate this file assumed at the top.
