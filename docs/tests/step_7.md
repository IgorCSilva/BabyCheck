# Manual Test Plan — Step 7: Charts Page

Scope: [roadmap.md](../base_content/roadmap.md) Step 7 — a dedicated page with one chart
per tracked metric (diaper, bottle, breastfeeding), stacked vertically, scoped to the
currently active baby and driven by a single shared date-range control. The backend adds
one new read-only endpoint, `GET /api/babies/:baby_id/charts`, backed by a new `Api.Charts`
context — like Step 6's `Api.Feed`, this reads the three existing per-metric tables rather
than adding a new one.

Two design points worth keeping in mind while testing:
- **Every day in the range is present, zero-filled.** `Api.Charts.daily_counts/3` always
  returns one entry per calendar day between `from` and `to`, even for days with no logs —
  Test 3 checks this explicitly with a gap day in the middle.
- **Chart colors are fixed per metric, not per baby.** Diaper is always sand
  (`#D9A066`), bottle always sky blue (`#6FAEDB`), breastfeeding always blush (`#E8899E`),
  regardless of which baby's data is shown — so the charts' meaning stays comparable across
  babies. Test 5 checks that switching the active baby doesn't change a chart's color.

Every test below assumes a logged-in account exists; most build up one account with two
babies (Riley, Sam) so the "charts are scoped to the active baby" behavior has something to
contrast against.

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
- A few tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering (no bearer token, another account's data, a malformed query
  param, exact known timestamps). Get a token the same way the UI does:
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
5. Go to `http://localhost:3000/charts` (or tap "Charts" in the top nav).

**Expected result:** you land on a "Trends" page with a shared date-range control (preset
tabs: Today / 7 days / 30 days / Custom, defaulting to "7 days") above three stacked cards
— "diaper changes," "bottle feedings," "breastfeeding sessions," each with its metric
icon — and every card currently shows "No data in this range yet," since nothing has been
logged.

---

## Positive cases

### Test 1 — Charts start with a friendly empty state for every metric

**Setup:** continue right after the setup above. Use a custom range of `2026-11-23` to
`2026-11-25` (the "Custom" tab) so the result is deterministic regardless of what day it
actually is.

**Steps**
```
curl -s "http://localhost:4000/api/babies/1/charts?from=2026-11-23T00:00:00Z&to=2026-11-25T23:59:59Z" \
  -H "Authorization: Bearer <token>"
```

**Expected result:** all three series are zero-filled across the three days, with no error:
```json
{
  "data": {
    "diaper": [
      {"date": "2026-11-23", "count": 0},
      {"date": "2026-11-24", "count": 0},
      {"date": "2026-11-25", "count": 0}
    ],
    "bottle": [
      {"date": "2026-11-23", "count": 0},
      {"date": "2026-11-24", "count": 0},
      {"date": "2026-11-25", "count": 0}
    ],
    "breastfeeding": [
      {"date": "2026-11-23", "count": 0},
      {"date": "2026-11-24", "count": 0},
      {"date": "2026-11-25", "count": 0}
    ]
  }
}
```

**Expected UI result:** all three cards show "No data in this range yet." instead of a
chart.

**Pass criteria:** an account with no logs yet never sees a broken or misleading chart —
just a plain, honest empty state, per metric.

---

### Test 2 — A log from a dedicated page shows up on its chart on the very next load

**Setup:** continue from Test 1.

**Steps (UI)**
1. Go to `/diapers`. Click "Log diaper change" twice.
2. Go to `/charts`.

**Expected UI result:** the "diaper changes" card now renders a bar chart (today's bar at
height 2); "bottle feedings" and "breastfeeding sessions" still show the empty state.

**Pass criteria:** a log made from its own dedicated page is immediately visible on its
chart — no separate sync step, same guarantee Step 6's feed gives for the merged list.

---

### Test 3 — Daily counts are bucketed correctly across metrics, with gap days zero-filled

**Setup:** continue from Test 2, using known timestamps via `curl` so the day-bucketing is
exact (substitute your own token and Riley's baby id, `1`).

**Steps**
```
curl -s -X POST http://localhost:4000/api/babies/1/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-23T08:00:00Z","peed":true,"pooped":false}'

curl -s -X POST http://localhost:4000/api/babies/1/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-23T20:00:00Z","peed":true,"pooped":true}'

curl -s -X POST http://localhost:4000/api/babies/1/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-25T08:00:00Z","peed":true,"pooped":false}'

curl -s -X POST http://localhost:4000/api/babies/1/bottle_feedings \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-24T09:00:00Z","water_ml":30,"formula_g":10}'

curl -s -X POST http://localhost:4000/api/babies/1/breastfeeding_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d '{"logged_at":"2026-11-25T10:00:00Z"}'

curl -s "http://localhost:4000/api/babies/1/charts?from=2026-11-23T00:00:00Z&to=2026-11-25T23:59:59Z" \
  -H "Authorization: Bearer <token>"
```

**Expected result** (note Nov 24 is a true gap day for diaper, and Nov 23/25 are gap days
for bottle and breastfeeding respectively — all correctly zero, not omitted):
```json
{
  "data": {
    "diaper": [
      {"date": "2026-11-23", "count": 2},
      {"date": "2026-11-24", "count": 0},
      {"date": "2026-11-25", "count": 1}
    ],
    "bottle": [
      {"date": "2026-11-23", "count": 0},
      {"date": "2026-11-24", "count": 1},
      {"date": "2026-11-25", "count": 0}
    ],
    "breastfeeding": [
      {"date": "2026-11-23", "count": 0},
      {"date": "2026-11-24", "count": 0},
      {"date": "2026-11-25", "count": 1}
    ]
  }
}
```

**Steps (UI):** on `/charts`, select "Custom," set the range to `11/23/2026`–`11/25/2026`.

**Expected UI result:** all three cards now render a bar chart (no empty state), each
showing the counts above across the three days in their own fixed accent color (sand /
sky blue / blush).

**Pass criteria:** counts land on the correct calendar day across all three metrics
independently, and a day with zero logs for one metric still appears as a labeled, zero
bar rather than a gap in the x-axis.

---

### Test 4 — The shared date-range control drives all three charts together

**Setup:** continue from Test 3.

**Steps (UI)**
1. On `/charts`, switch between "Today," "7 days," "30 days," and back to "Custom."

**Expected UI result:** changing the preset immediately refetches and re-renders all three
charts at once (not one at a time or on a delay) — e.g. switching to "Today" collapses all
three to a single day's bar, confirmed live.

**Pass criteria:** one control updates every chart together, exactly as the roadmap's
design note specifies, rather than three independent range pickers.

---

### Test 5 — Switching the active baby changes the data but never a chart's color

**Setup:** continue from Test 3 (Riley has logs; Sam has none). Keep the Custom range at
`2026-11-23`–`2026-11-25`.

**Steps (UI)**
1. With Riley active, note the diaper chart's bar color (sand) and bottle chart's bar
   color (sky blue).
2. Tap Sam's avatar in the switcher.

**Expected UI result**
- All three cards immediately switch to "No data in this range yet." (Sam has no logs),
  confirming the charts are scoped to the active baby, not merged across babies like
  Step 6's feed.
- Switching back to Riley re-renders Riley's bars in exactly the same sand/sky-blue/blush
  colors as before — confirmed live via screenshot comparison — regardless of either
  baby's own theme color (soft pink for Riley, sky blue for Sam, which happens to
  coincide with the bottle accent but is not the source of it).

**Pass criteria:** chart colors are a fixed property of the metric, never the active
baby's theme color, so a parent comparing two children's charts side by side isn't
confused by the bars changing color between them.

---

## Negative cases

### Test 6 — Another account's logs never appear in your charts

**Setup**
1. Sign up a second account: `parent2@example.com` / `supersecret123`.

**Steps**
```
curl -s -i "http://localhost:4000/api/babies/1/charts" -H "Authorization: Bearer <parent2_token>"
```

**Expected result:** `404`, since baby id `1` (Riley) doesn't belong to `parent2`'s
account — confirmed live.

**Pass criteria:** chart data is scoped to the authenticated user's own babies
server-side, the same ownership guarantee every other per-baby endpoint enforces.

---

### Test 7 — The charts endpoint requires authentication

**Steps**
```
curl -s -i "http://localhost:4000/api/babies/1/charts"
```

**Expected result:** `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`
— confirmed live.

**Pass criteria:** the API enforces authentication on its own, not only via the frontend's
route guard.

---

## Validation / edge cases

### Test 8 — Malformed or missing range params fall back to the last 7 days instead of erroring

**Steps**
```
curl -s -i "http://localhost:4000/api/babies/1/charts?from=not-a-date&to=also-not" \
  -H "Authorization: Bearer <token>"

curl -s "http://localhost:4000/api/babies/1/charts" -H "Authorization: Bearer <token>"

curl -s "http://localhost:4000/api/babies/1/charts?from=2026-11-25T00:00:00Z&to=2026-11-20T00:00:00Z" \
  -H "Authorization: Bearer <token>"
```

**Expected result:** all three return `200`, each with exactly 7 zero-or-counted days per
metric (the last-7-days default) — confirmed live for malformed strings, omitted params,
and an inverted (`from` after `to`) range.

**Pass criteria:** a garbled query string, a missing param, or a backwards range all
degrade to a sane default view rather than a `400`/`500`.

---

### Test 9 — Deleting a log is reflected on its chart on the next fetch

**Setup:** continue from Test 3 (Riley has 2 diaper logs on `2026-11-23`).

**Steps**
```
# id of one of the two 2026-11-23 diaper logs:
curl -s -o /dev/null -w "%{http_code}" -X DELETE \
  http://localhost:4000/api/diaper_logs/<id> -H "Authorization: Bearer <token>"

curl -s "http://localhost:4000/api/babies/1/charts?from=2026-11-23T00:00:00Z&to=2026-11-23T23:59:59Z" \
  -H "Authorization: Bearer <token>"
```

**Expected result:** the delete returns `204`, and the diaper count for `2026-11-23` drops
from `2` to `1` on the very next fetch — confirmed live.

**Pass criteria:** charts always reflect live data from the three source tables — there is
no separate cached/denormalized aggregate to fall out of sync.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Fresh baby, no logs, explicit range | Every metric zero-filled across the range; UI shows "No data in this range yet" per card |
| 2 | One log from a dedicated page | Appears on its chart immediately; other two stay empty |
| 3 | Known cross-metric timestamps with a gap day | Each metric's counts land on the correct day; gap days are zero-filled, not omitted |
| 4 | Switching preset tabs | All three charts refetch and re-render together from one control |
| 5 | Switching active baby | Data changes to the new baby's own logs; chart colors stay fixed (sand/sky blue/blush) regardless of either baby's theme color |
| 6 | Another account's baby id | `404` |
| 7 | Charts endpoint with no token | `401 unauthenticated` |
| 8 | Malformed / missing / inverted range params | `200`, falls back to the last 7 days |
| 9 | Delete a log | Its day's count decreases on the next fetch |

If every row holds, Step 7 delivers trend visibility on top of Steps 3–6's data: a parent
can see patterns over time, not just totals or a chronological list — the same three
tables read a third way, with no new migration required.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's tests
can start from the same clean slate this file assumed at the top.
