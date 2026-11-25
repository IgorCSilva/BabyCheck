# Manual Test Plan — Step 3: Diaper Log

Scope: [roadmap.md](../base_content/roadmap.md) Step 3 — logging a diaper change with one
tap, editing/deleting entries after the fact, and a dedicated page that lists entries by
day and totals them over a selected date range. This builds directly on Step 2
([step_2.md](step_2.md)): every test below assumes a logged-in account with at least one
baby already exists.

One design point worth keeping in mind while testing: **the one-tap button never asks for
anything up front.** `peed` and `pooped` default to `true` and the timestamp defaults to
"now," entirely server-side — any correction (wrong time, only one of the two happened) is
an *edit after the fact*, never a required step before the tap is accepted. Several tests
below check that this default lives on the API, not just in the form.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- Mailpit isn't needed for this step — nothing here sends email.
- **Start from an empty database.** This file assumes zero users, babies, and diaper logs
  before Test 1. If you're re-running this file, empty it first with the snippet below
  (the same one this file's [Cleanup](#cleanup) section ends with).
- All DB verification below uses `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.DiaperLogs.DiaperLog
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
4. Go to `http://localhost:3000/`. Click "Go to diaper log."

**Expected result:** you land on `/diapers` with a header reading "0 diaper changes," a
row of range tabs (Today / 7 days / 30 days / Custom) with "Today" active, a "Log diaper
change" button, and an empty-state message — this starting point is what Test 1 checks
explicitly.

---

## Positive cases

### Test 1 — The diaper log page starts empty for a brand new baby

**Setup:** continue right after the setup above.

**Steps (UI)**
1. Look at the range header and the list area below the quick-log button.

**Expected UI result**
- The big number reads `0`.
- Below the quick-log button: "No diaper changes in this range yet."

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 0
```
**Pass criteria:** zero diaper logs in the database, matching the empty UI.

---

### Test 2 — One tap logs a diaper change with sensible defaults

**Setup:** continue from Test 1, still on `/diapers`.

**Steps (UI)**
1. Click "Log diaper change."

**Expected UI result**
- Immediately: a dark toast appears at the bottom reading "Diaper logged" with an "Undo"
  link, and the button's Nightlight Glow pulses once in the baby's theme color (soft
  pink).
- A new row appears under a "Today" day header showing the current time, with "Peed" and
  "Pooped" both listed.
- The range total updates to `1`.
- The toast disappears on its own after a few seconds if left alone.

**Backend verification**
```elixir
log = Repo.one(from d in DiaperLog)
log.peed      # => true
log.pooped    # => true
log.baby_id   # => Riley's id
```
**Pass criteria:** the tap required no form and no fields, yet produced a fully-formed,
persisted record — exactly the "one tap, nothing required first" guarantee the design
calls for.

---

### Test 3 — A second entry stacks under the same day header and the total updates

**Setup:** continue from Test 2.

**Steps (UI)**
1. Click "Log diaper change" again.

**Expected UI result**
- Two rows now show under the single "Today" header, newest on top.
- The range total reads `2`.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 2
```
**Pass criteria:** entries for the same day group together under one header instead of
duplicating headers, and the total reflects every entry in the range, not just the latest.

---

### Test 4 — Editing an entry updates it in place, not as a new row

**Setup:** continue from Test 3 (two entries today).

**Steps (UI)**
1. Wait for the first row's "Edit"/"Delete" links to become enabled (they're disabled
   while that row is still the optimistic placeholder from Test 3's tap).
2. Click "Edit" on that row.
3. Uncheck "Peed," leave "Pooped" checked, adjust the time field, and click "Save."

**Expected UI result**
- While editing, the row becomes an inline form with a datetime field and the two
  checkboxes.
- After saving, the row shows only "Pooped" (not "Peed"), and the row count stays at 2 —
  no third row appears.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 2 (still two rows — this was an update, not an extra insert)
```
**Pass criteria:** the same row was updated; editing is how a tap's defaults get
corrected, exactly as the roadmap's "edit after the fact" design intends.

---

### Test 5 — Switching the range preset changes which entries count

**Setup:** continue from Test 4 (two entries, both logged just now, so both are "today").

**Steps (UI)**
1. Click the "Custom" tab. Two date inputs appear.
2. Set both the "from" and "to" date to yesterday's date. Confirm the total drops to `0`
   and the list shows the empty-state message.
3. Click "Today" again.

**Expected UI result**
- Step 2's custom range (yesterday only) shows `0` and the empty state, since both
  entries happened today.
- Switching back to "Today" immediately restores both rows and the `2` total.

**Pass criteria:** the displayed total is always a live `COUNT` over whatever range is
selected, not a cached or stored running total — narrowing the range changes it without
losing any underlying data.

---

## Negative cases

### Test 6 — Undo removes the entry, even if clicked before the request finishes

**Setup:** continue from Test 5 (on `/diapers`, "Today" selected, two entries exist).

**Steps (UI)**
1. Click "Log diaper change" a third time.
2. As soon as the toast appears, click "Undo" immediately.

**Expected UI result**
- The row briefly appears (the optimistic insert), then disappears once "Undo" is
  clicked.
- The range total returns to `2` — back to where it was before this tap.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 2 (the undone entry never persists, or is deleted right after it does)
```
**Pass criteria:** "Undo" reliably removes the optimistic entry both from the screen and
from the database, regardless of whether the create request had already completed when
the click happened.

---

### Test 7 — An invalid field value is rejected by the API

The UI can never actually send a non-boolean for `peed`/`pooped` (checkboxes only produce
`true`/`false`), so this is checked directly against the API. Using one of the two log ids
from Test 4:

**Steps**
```
curl -s -X PUT http://localhost:4000/api/diaper_logs/<log_id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"peed":"not-a-boolean"}'
```

**Expected result**
- `422` with `{"errors":{"peed":["is invalid"]}}`.

**Pass criteria:** the API validates field types server-side, independent of whatever the
UI's own inputs happen to restrict a user to.

---

### Test 8 — One account can't view, edit, or delete another account's diaper logs

**Setup**
1. Sign up a second account (in a private/incognito window, so it doesn't disturb session
   A): `parent2@example.com` / `supersecret123`, add a baby named `Other`, and log one
   diaper change for it.
2. Note `Other`'s baby id and that log's id from session B's own `/api/babies` and
   `/api/babies/<other_baby_id>/diaper_logs` responses.

**Steps**
```
# Using parent@example.com's token against parent2's baby/log ids:
curl -s -i http://localhost:4000/api/babies/<other_baby_id>/diaper_logs \
  -H "Authorization: Bearer <parent_token>"

curl -s -i -X PUT http://localhost:4000/api/diaper_logs/<other_log_id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <parent_token>" \
  -d '{"peed":false}'

curl -s -i -X DELETE http://localhost:4000/api/diaper_logs/<other_log_id> \
  -H "Authorization: Bearer <parent_token>"
```

**Expected result**
- All three calls return `404` with `{"errors":{"detail":"not found","code":"not_found"}}`
  — not a `403`, so the response doesn't even confirm a log with that id exists.

**Backend verification**
```elixir
log = Repo.one(from d in DiaperLog, where: d.baby_id == ^other_baby_id)
log.peed  # => still true (unchanged)
Repo.aggregate(from(d in DiaperLog, where: d.baby_id == ^other_baby_id), :count)
# => 1 (the DELETE never ran)
```
**Pass criteria:** every diaper-log lookup is scoped by the authenticated user's own baby
ownership server-side — a log id or baby id alone is never enough to read or change it.

---

## Validation / edge cases

### Test 9 — Deleting an entry removes it everywhere

**Setup:** continue session A from Test 6 (two entries, total `2`).

**Steps (UI)**
1. Click "Delete" on either row and confirm the browser prompt.

**Expected UI result**
- The row disappears immediately, the total drops to `1`.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 1
```
**Pass criteria:** the delete persists server-side, not just visually.

---

### Test 10 — An entry outside the selected range is excluded from the total, not from the database

**Setup:** continue from Test 9 (one entry remains, logged today).

**Steps**
1. Via `iex`, backdate the remaining log so it falls outside "today":
   ```elixir
   log = Repo.one(from d in DiaperLog)
   yesterday = DateTime.add(DateTime.utc_now(), -1, :day) |> DateTime.truncate(:second)
   {:ok, _} = log |> Ecto.Changeset.change(logged_at: yesterday) |> Repo.update()
   ```
2. Reload `/diapers` with "Today" selected.
3. Click the "7 days" tab.

**Expected UI result**
- On "Today": the total reads `0` and the empty state shows, even though a log exists.
- On "7 days": the total reads `1` again, and the row reappears under a "Yesterday"
  header.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 1 (still there the whole time — only the displayed range changed)
```
**Pass criteria:** range filtering happens entirely in the `from`/`to` query sent to the
API — nothing is ever deleted or hidden just because it's outside the currently selected
window.

---

### Test 11 — A non-numeric log id is rejected as "not found," not a server error

**Steps**
```
curl -s -i -X PUT http://localhost:4000/api/diaper_logs/not-a-number \
  -H "Authorization: Bearer <token>" \
  -d '{"peed":false}'

curl -s -i -X DELETE http://localhost:4000/api/diaper_logs/not-a-number \
  -H "Authorization: Bearer <token>"
```

**Expected result**
- Both return `404` with `{"errors":{"detail":"not found","code":"not_found"}}` — not a
  `500`.

**Pass criteria:** a malformed id is handled gracefully instead of crashing the request
(the kind of input a careless script or a tampered URL might send).

---

## Security / session cases

### Test 12 — Every diaper-log endpoint requires authentication

**Steps**
```
curl -s -i http://localhost:4000/api/babies/1/diaper_logs
curl -s -i -X POST http://localhost:4000/api/babies/1/diaper_logs
curl -s -i -X PUT http://localhost:4000/api/diaper_logs/1 -d '{"peed":false}'
curl -s -i -X DELETE http://localhost:4000/api/diaper_logs/1
```

**Expected result**
- All four return `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`.

**Pass criteria:** the API enforces authentication on every diaper-log action on its own —
this isn't only a frontend-side gate.

---

### Test 13 — Omitting the body on create still produces a fully-defaulted log

This is the API-level proof behind Test 2's UI behavior: the "one tap, nothing required"
guarantee is owned by the server, not just by the fact that the button happens to send no
fields.

**Steps**
```
curl -s -X POST http://localhost:4000/api/babies/<baby_id>/diaper_logs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{}'
```

**Expected result**
- `201` with a body like
  `{"data":{"id":<id>,"baby_id":<baby_id>,"logged_at":"<now, ISO 8601>","peed":true,"pooped":true}}`.

**Pass criteria:** a request with a completely empty body is accepted and defaulted —
confirming a client bug that forgets to send a field could never block a one-tap log from
succeeding.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Fresh baby, no logs | `0` total; empty-state message |
| 2 | One-tap log | Toast + glow pulse; row with Peed/Pooped; total `1`, fully defaulted server-side |
| 3 | Second one-tap log | Stacks under the same day header; total `2` |
| 4 | Edit an entry | Updates in place; row count unchanged |
| 5 | Switch range preset | Total reflects only the selected window |
| 6 | Undo | Entry removed from screen and DB, even if clicked early |
| 7 | Invalid field value | Rejected, `422` |
| 8 | View/edit/delete another account's logs | `404` every time, ownership enforced server-side |
| 9 | Delete an entry | Removed from list, total, and DB |
| 10 | Entry outside selected range | Excluded from the total, still in the DB |
| 11 | Non-numeric id | `404 not_found`, not a crash |
| 12 | Diaper-log endpoints with no token | `401 unauthenticated` on every verb |
| 13 | Create with an empty body | `201`, fully defaulted (`peed`/`pooped` `true`, `logged_at` now) |

If every row holds, Step 3's diaper log is safe to build the bottle- and
breastfeeding-logging steps on top of: the one-tap/no-required-fields guarantee lives on
the server, ownership is enforced the same way Step 2 established for babies themselves,
and range totals are always a live count rather than a value that could drift out of sync
with the underlying rows.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so Step 4's tests can
start from the same clean slate this file assumed at the top.
