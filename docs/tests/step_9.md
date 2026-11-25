# Manual Test Plan — Step 9: Smart Interval Insights & Reminders

Scope: [roadmap.md](../base_content/roadmap.md) Step 9 — Step 6's feed chips (already
showing "time since last X" per metric) now also show a rolling 7-day daily average, and
quietly flag a metric whose gap since the last log is unusually long given that average.
An Oban job (`Api.Insights.ComputeInsightsWorker`) recomputes and stores the same numbers
for every baby on a schedule, independent of anyone having the app open; the feed itself
always reads a fresh, live computation (`Api.Insights.compute_for_baby/1`) rather than the
stored copy, so the chips are never stale behind the job's own cadence.

One scope note worth keeping in mind while testing:
- **The reminder notification itself is out of scope for this step.** The roadmap's own
  Tech section says Web Push "requires Step 10's PWA shell," which doesn't exist yet. What
  this step delivers is everything a future push notification would need to decide
  *whether* to fire — the rolling average and the `long_gap` flag, computed live for the
  UI and persisted on a schedule by the Oban job. Test 6 checks that stored side directly.

Every test below assumes a logged-in account with one baby, since the chips are an
extension of Step 6's existing per-baby stat strip.

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
- Several tests seed logs with exact, backdated timestamps via `curl`, since "unusually
  long gap since now" can't be set up any other way deterministically. Get a bearer token
  the same way the UI does:
  ```
  curl -s -X POST http://localhost:4000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"<email>","password":"<password>"}'
  ```
  The response body's `data.access_token` is your bearer token. Each seeding command below
  computes its own timestamp relative to *right now* with `date -u -d '-N hours'`, so the
  numbers in "expected result" stay correct no matter what day you actually run this.
- A couple of tests confirm server-side state the UI can't show you directly, via
  `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.Insights
  alias Api.Insights.Insight
  ```

### Resetting the database to empty

Truncates every application table (everything except `schema_migrations`) without
dropping/recreating the database or restarting any container:

```
docker compose exec api iex -S mix
```
```elixir
alias Api.Repo

{:ok, %{rows: rows}} =
  Ecto.Adapters.SQL.query(Repo, "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('schema_migrations', 'oban_jobs', 'oban_peers')")

tables = List.flatten(rows)
Ecto.Adapters.SQL.query!(Repo, "TRUNCATE TABLE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE")
```

### Creating the account and baby these tests share

1. Open `http://localhost:3000/signup`.
2. Email `parent@example.com`, Password `supersecret123`, Confirm password
   `supersecret123`. Submit.
3. On the `/babies` page you land on, add Name `Riley`, pick the first swatch (soft pink).
   Submit.
4. Log in via `curl` as above to get a bearer token for the seeding steps below. Riley's
   baby id is `1` on a freshly-reset database.
5. Go to `http://localhost:3000/` (the home feed).

**Expected result:** the stat strip shows Riley with three chips (🧷 🍼 🤱), each reading
"No logs yet" and showing no average — identical to Step 6's behavior before this step,
since nothing has been logged yet.

---

## Positive cases

### Test 1 — A rolling average appears once there's enough recent history

**Setup:** continue right after the setup above.

**Steps**
```
for H in 72 96 120 144 160; do
  TS=$(date -u -d "-${H} hours" +%Y-%m-%dT%H:%M:%SZ)
  curl -s -X POST http://localhost:4000/api/babies/1/diaper_logs \
    -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
    -d "{\"logged_at\":\"${TS}\"}"
done
```
Then reload `http://localhost:3000/`.

**Expected UI result:** the diaper chip (🧷) now reads "3d ago" on one line and
"0.7/day avg" in smaller, muted text underneath — five logs over the last 7 days average
to 5 ÷ 7 ≈ 0.7/day, and the most recent of the five is 72 hours (3 days) old.

**Pass criteria:** the average is computed from real history and shown quietly alongside
the existing "time since last" text, not replacing it.

---

### Test 2 — A metric with no history at all still shows nothing extra

**Setup:** continue from Test 1 (bottle and breastfeeding have never been logged).

**Steps (UI)**
1. Look at the bottle (🍼) and breastfeeding (🤱) chips next to the diaper one.

**Expected UI result:** both still read plain "No logs yet," exactly like Step 6, with no
average line and no highlight — a metric that's never happened has nothing to be ambient
about yet.

**Pass criteria:** the new average/gap UI is purely additive — a metric with zero history
looks exactly as it did before this step.

---

### Test 3 — An unusually long gap is flagged quietly, not as an alert

**Setup:** continue from Test 1. Five diaper logs roughly a day apart establish an
expected gap of about 24 hours; the most recent one is 72 hours old, well past double that.

**Steps (UI)**
1. Look closely at the diaper chip's background compared to the bottle/breastfeeding
   chips: it's a visibly more saturated sand than the usual 16%-opacity fill.
2. Hover (desktop) or long-press (mobile) the diaper chip.

**Expected UI result:** a tooltip reads "Longer than usual since the last one." Nothing
flashes, changes color to a warning hue, or otherwise reads as an alert — just a slightly
stronger fill and a hover hint, per the roadmap's "ambient, not an alert" design note.

**Backend verification**
```elixir
baby = Repo.get!(Api.Babies.Baby, 1)
Insights.compute_for_baby(baby)
# => %{diaper: %{avg_per_day_7d: 0.714285..., long_gap: true, last_logged_at: ~U[...]}, bottle: ..., breastfeeding: ...}
```

**Pass criteria:** `long_gap` is computed and surfaced correctly, and the UI treatment
matches the "quiet, not urgent" design intent rather than looking like an error state.

---

### Test 4 — Logging again clears the flag immediately, no reload needed

**Setup:** continue from Test 3, on the home feed (`/`).

**Steps (UI)**
1. Tap the diaper button (🧷) in the global quick-log bar.

**Expected UI result:** without reloading the page, the diaper chip updates to "Just now,"
the long-gap highlight disappears, and the average line updates too (now 6 logs over 7
days). This relies on the same feed-refresh wiring the quick-log bar already uses after
every log (see Step 8's fix for Feed/Charts going stale) — the summary re-fetch just
happens to carry the new insight fields along with it now.

**Pass criteria:** insight chips are exactly as live as the "time since last" text they
sit next to — no separate staleness class for the new fields.

---

### Test 5 — A single stray log doesn't invent a false "routine"

**Setup:** reset the database (see [above](#resetting-the-database-to-empty)) and redo
only steps 1–3 of the account setup (a fresh Riley, no logs yet).

**Steps**
```
TS=$(date -u -d "-144 hours" +%Y-%m-%dT%H:%M:%SZ)
curl -s -X POST http://localhost:4000/api/babies/1/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer <token>" \
  -d "{\"logged_at\":\"${TS}\"}"
```
Reload `http://localhost:3000/`.

**Expected UI result:** the diaper chip reads "6d ago" and a small "0.1/day avg" — but is
**not** highlighted as a long gap, even though six days is a long time, because one log in
a week isn't enough history to call it "unusual" yet.

**Backend verification**
```elixir
baby = Repo.get!(Api.Babies.Baby, 1)
Insights.compute_for_baby(baby)
# => %{diaper: %{avg_per_day_7d: 0.142857..., long_gap: false, ...}, ...}
```

**Pass criteria:** `long_gap` requires a minimum baseline frequency before it can fire —
sparse, irregular logging never gets flagged just for having a gap.

---

## Backend / scheduled job

### Test 6 — The Oban job persists the same insight independent of the app being open

**Setup:** continue from Test 3's state (reset the DB and redo Test 1's seeding if you
ran Test 5 in between).

**Steps**
```elixir
:ok = Api.Insights.ComputeInsightsWorker.perform(%Oban.Job{})
Repo.all(Insight) |> Enum.map(&{&1.baby_id, &1.metric, &1.long_gap})
Insights.list_long_gap()
```

**Expected result:** one stored `Insight` row per baby per metric (3 rows for Riley
alone); `list_long_gap/0` returns exactly the diaper row for Riley, matching what Test 3's
live computation already showed. This is the data a future Step 10 push notification
would query — the job keeps it warm on its own schedule (`config :api, Oban` runs it every
10 minutes) with nobody needing the app open.

**Pass criteria:** the scheduled computation and the feed's live computation agree, and
the job runs correctly when invoked directly (as `Oban.Plugins.Cron` will on its own
schedule in a real deployment).

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Seed 5 diaper logs over the last ~7 days | Chip shows "3d ago" + "0.7/day avg" |
| 2 | Metrics with zero history | Still plain "No logs yet," no average, no highlight |
| 3 | A gap more than double the expected interval | Chip quietly highlighted + tooltip, no alert styling |
| 4 | Log again from the quick-log bar | Flag and average update live, no reload |
| 5 | A single old log, no baseline | Average shown, but `long_gap` stays false |
| 6 | Run the Oban worker directly | Stored insights match the live computation; `list_long_gap/0` returns only the flagged metric |

If every row holds, Step 9 delivers what the roadmap asks for short of the notification
transport itself: the app computes and quietly surfaces what it knows about each baby's
rhythm, live in the UI and durably in the background, ready for Step 10 to wire a real
push notification on top of.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
