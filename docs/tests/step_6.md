# Manual Test Plan — Step 6: Global Feed

Scope: [roadmap.md](../base_content/roadmap.md) Step 6 — a single home feed that merges
the three per-metric log tables (diaper, bottle, breastfeeding) across every baby on an
account, ordered newest-first and paginated, plus a per-baby "time since last" stat strip
pinned above the list. This is the first step to read *across* Steps 3–5's tables rather
than add a new one — there is no new migration here, only a `Api.Feed` context that
queries the existing three. The feed is also the account's new default landing page
(`/`), replacing the old static welcome card.

Two design points worth keeping in mind while testing:
- **The merge is exact, not approximate.** The three tables are fetched independently
  (each already sorted `logged_at desc`), then merged and re-sorted in Elixir. Test 3
  specifically checks that entries from different tables interleave correctly by time,
  not just within each table.
- **The stat strip updates on its own.** While the feed page stays mounted, it polls
  `/api/feed/summary` every 15 seconds; a chip whose "last logged" timestamp just changed
  briefly takes the Nightlight Glow, so a log landing from another tab/device shows up
  without a manual refresh. Test 7 checks this specifically.

Every test below assumes a logged-in account exists; most build up one account with two
babies (Riley, Sam) so multi-baby merging has something to show.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- Mailpit isn't needed for this step — nothing here sends email.
- **Start from an empty database.** This file assumes zero users, babies, and logs before
  Test 1. If you're re-running this file, empty it first with the snippet below (the same
  one this file's [Cleanup](#cleanup) section ends with).
- All DB verification below uses `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  alias Api.DiaperLogs.DiaperLog
  alias Api.BottleFeedings.BottleFeeding
  alias Api.BreastfeedingLogs.BreastfeedingLog
  import Ecto.Query
  ```
- A few tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering (no bearer token, another account's data, a malformed query
  param, more entries than fit on one page). Get a token the same way the UI does:
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

### Creating the account and babies these tests share

1. Open `http://localhost:3000/signup`.
2. Email `parent@example.com`, Password `supersecret123`, Confirm password
   `supersecret123`. Submit.
3. On the `/babies` page you land on, add Name `Riley`, pick the first swatch (soft pink).
   Submit.
4. Still on `/babies`, add a second baby, Name `Sam`, pick the second swatch (sky blue).
   Submit.
5. Go to `http://localhost:3000/`.

**Expected result:** you land on `/` (the feed — this is now the default landing page)
with a "Recent activity" heading, a stat-strip card listing both Riley and Sam each with
three chips (diaper/bottle/breastfeeding, all reading "No logs yet"), and an empty-state
message below — this starting point is what Test 1 checks explicitly.

---

## Positive cases

### Test 1 — The feed starts empty, with "no logs yet" chips for every baby and metric

**Setup:** continue right after the setup above.

**Steps (UI)**
1. Look at the stat strip and the list area below it.

**Expected UI result**
- The stat strip shows one row per baby (Riley, Sam), each with a colored dot in that
  baby's theme color and three chips — 🧷 diaper, 🍼 bottle, 🤱 breastfeeding — all reading
  "No logs yet".
- Below the stat strip: "No activity yet. Start logging to see it here."

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
Repo.aggregate(from(b in BottleFeeding), :count)
Repo.aggregate(from(b in BreastfeedingLog), :count)
# => 0, 0, 0
```
**Pass criteria:** the feed and stat strip both reflect a true empty state across every
baby and metric, not just the active one.

---

### Test 2 — A single log from one metric appears in the feed immediately

**Setup:** continue from Test 1.

**Steps (UI)**
1. Switch to Riley (if not already active) and go to `/diapers`. Click "Log diaper
   change."
2. Go back to `http://localhost:3000/`.

**Expected UI result**
- One row appears in the list: Riley's dot, the 🧷 icon, Riley's name, and "Just now."
- In the stat strip, Riley's diaper chip now reads "Just now" instead of "No logs yet";
  Riley's other two chips and all of Sam's chips are unchanged.

**Pass criteria:** a log made from its own dedicated page is immediately visible from the
feed on the very next load — no separate "sync" step.

---

### Test 3 — Entries from different metrics and different babies interleave by time, not by table

**Setup:** start from an empty database (this test's ordering needs exact, known
timestamps, which the UI's "now"-only quick-log can't produce — use `curl` against the
account/babies from the setup above, substituting your own token and baby ids).

**Steps**
```
curl -s -X POST http://localhost:4000/api/babies/<riley_id>/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-24T08:00:00Z","peed":true,"pooped":false}'

curl -s -X POST http://localhost:4000/api/babies/<sam_id>/bottle_feedings \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-24T09:00:00Z","water_ml":60,"formula_g":15}'

curl -s -X POST http://localhost:4000/api/babies/<riley_id>/breastfeeding_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-24T10:00:00Z"}'

curl -s http://localhost:4000/api/feed -H "Authorization: Bearer <token>"
```

**Expected result:** `data` has exactly 3 entries, newest first regardless of which table
they came from:
```json
[
  {"type":"breastfeeding","baby_id":1,"baby_name":"Riley","logged_at":"2026-11-24T10:00:00Z", "...": "..."},
  {"type":"bottle","baby_id":2,"baby_name":"Sam","water_ml":60,"formula_g":15,"logged_at":"2026-11-24T09:00:00Z", "...": "..."},
  {"type":"diaper","baby_id":1,"baby_name":"Riley","peed":true,"pooped":false,"logged_at":"2026-11-24T08:00:00Z", "...": "..."}
]
```
Each entry also carries `baby_theme_color`, and the fields that don't apply to its own
`type` (e.g. `water_ml`/`formula_g` on a diaper entry, `peed`/`pooped` on a bottle entry)
are `null` rather than omitted.

**Reloading `/` in the UI** shows the same three rows in the same order, the bottle row
showing "60ml · 15g," and the stat strip's `diaper_last_logged_at`/`bottle_last_logged_at`
/`breastfeeding_last_logged_at` matching each of the three timestamps above per baby.

**Pass criteria:** the merge-then-sort is correct across tables and babies — the newest
entry overall wins regardless of which table it lives in, confirming the feed isn't just
three tables' lists concatenated.

---

### Test 4 — Pagination: a page is capped, and the cursor picks up exactly where it left off

**Setup:** continue from Test 3 (3 entries exist). Add 25 more diaper logs for Riley with
distinct timestamps, one per day:
```
for i in $(seq -w 1 25); do
  curl -s -o /dev/null -X POST http://localhost:4000/api/babies/<riley_id>/diaper_logs \
    -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
    -d "{\"logged_at\":\"2026-10-${i}T08:00:00Z\"}"
done
```
(28 entries total now: 25 new + the 3 from Test 3.)

**Steps**
```
curl -s http://localhost:4000/api/feed -H "Authorization: Bearer <token>"
```
Take the `logged_at` of the last (28th→ really the 20th, last-of-page) entry returned,
call it `<cursor>`, then:
```
curl -s "http://localhost:4000/api/feed?before=<cursor>" -H "Authorization: Bearer <token>"
```

**Expected result**
- The first call returns exactly 20 entries (the default page size), newest first.
- The second call returns the remaining 8, starting strictly *after* `<cursor>` — the
  entry with `logged_at` equal to `<cursor>` itself does not reappear.

**Steps (UI)**
1. Reload `/`. Scroll the list to the bottom.

**Expected UI result:** more rows load automatically as the bottom comes into view (no
"Load more" button to click), until all 28 are visible.

**Pass criteria:** pages are capped at a sane size instead of returning everything at
once, and the cursor is exclusive — scrolling further never reloads an entry already on
screen.

---

### Test 5 — A fresh log from another tab updates the stat strip without a manual reload

**Setup:** continue from Test 4. Open `http://localhost:3000/` in one tab and leave it
open. Open `/diapers` in a second tab of the *same* browser (same session).

**Steps**
1. In the second tab, click "Log diaper change."
2. Switch back to the first tab (the feed) and wait up to ~15 seconds without reloading.

**Expected UI result**
- Riley's diaper chip updates to "Just now" on its own.
- At the moment it updates, the chip briefly glows (the same Nightlight Glow pulse used
  elsewhere in the app), in Riley's theme color, then settles back to normal after about
  a second and a half.

**Pass criteria:** the feed page visibly confirms a log that happened elsewhere without
requiring the user to refresh — the behavior the roadmap's "chip briefly takes the
Nightlight Glow" design note calls for.

---

## Negative cases

### Test 6 — Another account's logs never appear in your feed or stat strip

**Setup**
1. Sign up a second account (in a private/incognito window, so it doesn't disturb session
   A): `parent2@example.com` / `supersecret123`, add a baby named `Other`, and log a
   diaper change for it.

**Steps**
```
curl -s "http://localhost:4000/api/feed?limit=100" -H "Authorization: Bearer <parent_token>"
```

**Expected result:** no entry in `data` has `"baby_name":"Other"` — the response contains
only `parent@example.com`'s own 28 entries from Test 4.

**Steps (UI):** reload `/` as `parent@example.com`.

**Expected UI result:** the stat strip still shows only Riley and Sam — no third baby row
appears.

**Pass criteria:** the feed is scoped to the authenticated user's own babies server-side,
the same ownership guarantee Steps 3–5 already enforce per-metric.

---

### Test 7 — Both feed endpoints require authentication

**Steps**
```
curl -s -i http://localhost:4000/api/feed
curl -s -i http://localhost:4000/api/feed/summary
```

**Expected result**
- Both return `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`.

**Pass criteria:** the API enforces authentication on its own — this isn't only a
frontend-side gate.

---

## Validation / edge cases

### Test 8 — Malformed pagination params fall back to defaults instead of erroring

**Steps**
```
curl -s -i "http://localhost:4000/api/feed?limit=abc&before=not-a-date" \
  -H "Authorization: Bearer <token>"
```

**Expected result:** `200`, with `data` containing the default-page-size (20) most recent
entries — exactly as if `limit`/`before` had been omitted entirely, not a `400`/`500`.

**Pass criteria:** a garbled query string (a stale bookmark, a tampered URL, a client
bug) degrades to "show the most recent page," never a crash.

---

### Test 9 — Deleting a log removes it from the feed on the very next fetch

**Setup:** continue from Test 4/6 (28 entries for `parent@example.com`).

**Steps**
```
# Using the id of the most recent (breastfeeding) entry from Test 3:
curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  http://localhost:4000/api/breastfeeding_logs/<id> -H "Authorization: Bearer <token>"

curl -s "http://localhost:4000/api/feed?limit=1" -H "Authorization: Bearer <token>"
```

**Expected result:** the delete returns `204`, and the subsequent single-entry fetch now
returns the bottle entry from Test 3 (the next-newest) instead of the deleted
breastfeeding entry.

**Pass criteria:** the feed always reflects live data from the three source tables — there
is no separate cached/denormalized feed table to fall out of sync.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Fresh account, two babies, no logs | Empty-state message; every chip reads "No logs yet" |
| 2 | One log from a dedicated page | Appears in the feed immediately; its chip updates |
| 3 | Mixed metrics/babies, known timestamps | Merged and sorted strictly by `logged_at desc`, correct fields per type |
| 4 | 28 entries, default page size 20 | First page capped at 20; `before` cursor returns the remaining 8, exclusive of the cursor itself; UI infinite-scrolls to load them |
| 5 | Log from a second tab while feed stays open | Stat chip updates and glows within ~15s, no reload |
| 6 | Another account's logs | Never appear in feed or stat strip |
| 7 | Feed endpoints with no token | `401 unauthenticated` on both |
| 8 | Malformed `limit`/`before` | `200`, falls back to the default first page |
| 9 | Delete a log | Disappears from the feed on the next fetch |

If every row holds, Step 6 delivers Phase 3's first milestone: a single landing page that
answers "what just happened across every child" without visiting Steps 3–5's three
separate pages — the foundation Step 7's charts page will read the same three tables
alongside.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so Step 7's tests can
start from the same clean slate this file assumed at the top.
