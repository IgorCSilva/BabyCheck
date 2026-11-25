# Manual Test Plan — Step 8: Global Quick-Log Bar

Scope: [roadmap.md](../base_content/roadmap.md) Step 8 — a persistent bar, mounted once
in the app shell and visible on every authenticated page with an active baby, offering
one tap-to-log button per metric (diaper / bottle / breastfeeding) for whichever baby is
currently active. There is **no new backend** in this step — it calls the exact same
per-metric log endpoints Steps 3–5 already built (`POST /api/babies/:baby_id/diaper_logs`,
`.../bottle_feedings`, `.../breastfeeding_logs`); the only thing that changed is *where*
in the UI you can trigger them from.

One design point worth keeping in mind while testing:
- **The single-button quick-log bar each of Steps 3–5 put at the bottom of its own
  dedicated page has been removed and replaced by this one global bar.** Having both
  would mean two different fixed-bottom-edge bars stacked (or overlapping) on the same
  three pages for the exact same action, which is why the per-page ones were retired
  rather than left in place alongside the new global one. Test 7 explicitly checks there
  is now exactly one quick-log affordance on those pages, not two.

Every test below assumes a logged-in account exists with at least one baby, since the bar
intentionally renders nothing without an active baby (Test 8 checks that directly).

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
- A couple of tests confirm server-side state a UI click can't show you directly, via
  `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.DiaperLogs.DiaperLog
  import Ecto.Query
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
5. Go to `http://localhost:3000/` (the home feed).

**Expected result:** a bar is docked to the bottom edge of the viewport with three
circular buttons — a sand diaper icon (🧷), a sky-blue bottle icon (🍼), and a blush
breastfeeding icon (🤱) — visible below the feed content, with Riley active.

---

## Positive cases

### Test 1 — Tapping a button logs instantly from a page that has nothing to do with that metric

**Setup:** continue right after the setup above. Riley is active, on `/` (the home feed).

**Steps (UI)**
1. Tap the diaper button (🧷) in the global bar.

**Expected UI result**
- A dark toast appears at the bottom reading "Diaper logged" with an "Undo" link, and the
  tapped button briefly shows a soft pink glow (Riley's theme color) around it.
- The toast disappears on its own after a few seconds if left alone.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 1
```
**Pass criteria:** a diaper change is logged without ever visiting `/diapers` — the whole
point of this step.

---

### Test 2 — Each button logs to its own metric, independent of the page you're on

**Setup:** continue from Test 1, now on `/charts`.

**Steps (UI)**
1. Tap the bottle button (🍼).
2. Tap the breastfeeding button (🤱).

**Expected UI result**
- Each tap shows its own toast ("Bottle feeding logged", then "Breastfeeding logged") and
  pulses the glow around the button that was actually tapped.

**Steps (UI, verification)**
3. Go to `/bottle-feedings` — one row, defaulted to `30ml · 10g` (no form shown, exactly
   one tap).
4. Go to `/breastfeeding` — one row.
5. Go to `/diapers` — still exactly the one row from Test 1 (untouched by these taps).

**Pass criteria:** tapping a given metric's button only ever creates a row in that
metric's own table, regardless of which page the tap happened from.

---

### Test 3 — The bar is visible on every authenticated page, not just the dedicated ones

**Setup:** continue from Test 2.

**Steps (UI)**
1. Visit `/`, `/diapers`, `/bottle-feedings`, `/breastfeeding`, `/charts`, and `/babies` in
   turn.

**Expected UI result:** the same three-button bar is docked at the bottom on all six
pages — it's part of the app shell, not something any individual page renders itself.

**Pass criteria:** "reachable from every page" is literally true, confirmed by visiting
every route that has an active baby in scope.

---

### Test 4 — Undo removes the entry, from any page

**Setup:** continue from Test 3, on `/charts`.

**Steps (UI)**
1. Tap the diaper button (🧷).
2. As soon as the toast appears, click "Undo" immediately.
3. Go to `/diapers`.

**Expected UI result:** the diaper log list still shows only the one row from Test 1 —
the row created by this test's tap and then undone never persists.

**Backend verification**
```elixir
Repo.aggregate(from(d in DiaperLog), :count)
# => 1 (unchanged from Test 1)
```
**Pass criteria:** undo works identically from the global bar as it did from each
dedicated page's own quick-log button in Steps 3–5 — nothing about that guarantee was
lost when the button moved.

---

### Test 5 — Logs always attribute to whichever baby is currently active

**Setup:** continue from Test 4. Riley has 1 diaper / 1 bottle / 1 breastfeeding log; Sam
has none.

**Steps (UI)**
1. On any page, tap Sam's avatar in the switcher to make Sam active.
2. Tap the diaper button (🧷).
3. Go to `/diapers` — note the total shown is `1` (Sam's own, brand-new count).
4. Switch back to Riley — the diaper total there still reads `1` (Riley's own Test 1 log;
   Sam's tap in this test never touched it, and Test 4's log was undone so it was never
   counted in the first place).

**Pass criteria:** the global bar always logs for the active baby, exactly like every
other quick-log affordance in the app — there's no way to accidentally log for the
wrong child because the bar itself has no baby-selection UI of its own.

---

### Test 6 — Button colors stay fixed per metric; only the glow follows the baby's theme

**Setup:** continue from Test 5. Riley (soft pink) and Sam (sky blue) both have at least
one log.

**Steps (UI)**
1. With Riley active, tap the bottle button (🍼) and note: the button's own fill is sky
   blue (the fixed bottle accent) and the glow that pulses around it is soft pink
   (Riley's theme), confirmed live via screenshot.
2. Switch to Sam (also sky blue) and tap the bottle button again — the button fill is
   identical to step 1 (still the fixed sky-blue accent, not re-derived from Sam's own
   theme color, which only coincidentally also happens to be sky blue), but the glow
   pulse is now Sam's own theme color.

**Pass criteria:** the three button fills never change — they're a fixed property of the
metric, exactly like Step 7's chart colors — while the glow is the one part of the bar
that reflects the active baby, per the roadmap's design note.

---

## Negative cases

### Test 7 — The dedicated pages no longer render their own duplicate quick-log button

**Setup:** continue from Test 6.

**Steps (UI)**
1. Go to `/diapers`, `/bottle-feedings`, and `/breastfeeding` in turn.

**Expected UI result:** on each page there is exactly one fixed-bottom-edge bar (the
global one, three buttons) — not two bars stacked, and not a lone single-metric button
alongside it.

**Pass criteria:** the consolidation described at the top of this file actually
happened — no leftover duplicate affordance from Steps 3–5.

---

### Test 8 — The bar renders nothing without an active baby

**Setup**
1. Sign up a brand-new account, `parent2@example.com` / `supersecret123`, and stop right
   after signup, before adding a baby.

**Steps (UI)**
1. Observe the `/babies` page you land on (with zero babies yet).

**Expected UI result:** no quick-log bar is visible anywhere on screen — there's no baby
to log for yet, so the bar has nothing useful to offer.

**Pass criteria:** the bar is conditioned on an active baby existing, not just on being
logged in, so a brand-new account is never shown three buttons that would silently fail
or error if tapped.

---

## Validation / edge cases

### Test 9 — A tap triggers a device vibration where supported, without blocking the log

**Setup:** continue from Test 6 (Riley active, on any page).

**Steps**
1. Open the browser's devtools console and run
   `let calls = []; navigator.vibrate = (ms) => { calls.push(ms); return true; };` to
   observe calls without needing a real vibration-capable device.
2. Tap any quick-log button.
3. In the console, inspect `calls`.

**Expected result:** `calls` contains exactly one short duration (tens of milliseconds),
and the toast/log still completed normally per Test 1 — the vibration call never gates
or delays the actual log request.

**Pass criteria:** `navigator.vibrate` is called as a side effect, optionally and
silently (`navigator.vibrate?.(...)`), confirming the app degrades gracefully on
browsers/devices that don't support it at all (it would simply be `undefined` there).

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Tap diaper button from the home feed | Logged without visiting `/diapers`; toast + glow shown |
| 2 | Tap bottle, then breastfeeding, from `/charts` | Each logs to its own table only; diaper count from Test 1 untouched |
| 3 | Visit every authenticated route | The same 3-button bar is present on all of them |
| 4 | Undo from a non-dedicated page | Entry never persists, confirmed on the dedicated page and in the DB |
| 5 | Switch active baby, then tap | Log is attributed to whichever baby is active at tap time |
| 6 | Compare button fill vs. glow color across babies | Button fill is always the fixed metric accent; only the glow follows the active baby's theme |
| 7 | Revisit the 3 dedicated pages | Exactly one quick-log bar each, not two |
| 8 | Fresh account, zero babies | No quick-log bar rendered at all |
| 9 | Stub `navigator.vibrate` and tap | Called once, briefly; doesn't block or delay the log |

If every row holds, Step 8 delivers on its own promise — logging never requires
navigating anywhere first — without regressing any guarantee Steps 3–5 already
established (one-tap defaults, optimistic insert + undo, baby-scoped attribution).

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
