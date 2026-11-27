# Manual Test Plan — Step 13: Growth Measurements (Weight & Height)

Scope: [roadmap.md](../base_content/roadmap.md) Step 13 — a dedicated "Growth" page where
a parent records occasional weight/height measurements (e.g. at a pediatrician visit),
not one-tap quick-logs. Each entry is editable and deletable, either value can be left
blank for a visit where only one was taken, and the page plots whatever's recorded as a
simple trend over time, alongside a chronological history list. A growth measurement also
shows up in the Home feed's activity timeline alongside the other three metrics, and the
Growth page has its own "Export PDF" button — a separate, growth-only PDF (full history,
weight/height trend charts, a measurements table), not bundled into the Step 12 export.

**Scope note:** storage is always metric (`weight_kg`, `height_cm`) regardless of UI
locale — switching language changes the unit *labels* only ("Kg" in pt-BR vs. "kg" in
English), never a unit-system conversion.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
- Any browser works for the UI tests below; a couple of edge-case tests call the API
  directly with `curl`.
- Get a bearer token the same way the UI does, for the `curl`-based tests:
  ```
  curl -s -X POST http://localhost:4000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"<email>","password":"<password>"}'
  ```
  The response body's `data.access_token` is your bearer token.
- **Start from an empty database.** This file assumes zero users before Test 1. If you're
  re-running this file, empty it first with the snippet below (the same one this file's
  [Cleanup](#cleanup) section ends with).

### Resetting the database to empty

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
4. You land on the home feed, `http://localhost:3000/`.
5. Go to `http://localhost:3000/growth` (the "Growth" tab in the top nav).

---

## Positive cases

### Test 1 — The Growth page has an add-measurement form and starts empty

**Setup:** continue right after the setup above, on the Growth page.

**Steps (UI)**
1. Look at the page.

**Expected UI result**
- An "Add a measurement" card is visible with a Weight (kg) field, a Height (cm) field
  (both blank), and a Date field defaulting to today.
- Below the form, "No growth measurements recorded yet." — no chart, no history list yet.

**Pass criteria:** the empty state is a normal, unalarming case, not an error.

---

### Test 2 — Recording weight and height together adds a history row and both trend charts

**Setup:** continue from Test 1.

**Steps (UI)**
1. Enter Weight `4.2`, Height `55`, set Date to `2026-11-20`.
2. Submit.

**Expected UI result**
- The form clears back to blank weight/height and today's date.
- A "Weight trend" chart and a "Height trend" chart both appear, each with a single point.
- Below them, a history list grouped under a "2026" header shows one row: `Nov 20, 2026`,
  `4.2kg`, `55cm`, with "Edit" and "Delete" actions.

**Pass criteria:** a single entry with both values populates the list row, both trend
charts, and the correct year group.

---

### Test 3 — An entry with only one value is accepted and shown correctly

**Setup:** continue from Test 2.

**Steps (UI)**
1. Enter Weight `5.1` only (leave Height blank), set Date to `2026-11-25`.
2. Submit.

**Expected UI result**
- A second history row appears (`Nov 25, 2026`, `5.1kg`, no height value shown), newest
  first within the "2026" group.
- The Weight trend chart now has two points; the Height trend chart still has only the
  one point from Test 2 (the weight-only entry doesn't appear on it).

**Pass criteria:** weight and height are independently optional per entry, and each trend
chart only plots the entries that actually have that value.

---

### Test 4 — Editing a measurement updates the row and both charts

**Setup:** continue from Test 3.

**Steps (UI)**
1. Click "Edit" on the `Nov 25, 2026` row.
2. Confirm the form now shows Weight `5.1`, blank Height, and that date — and the form
   title reads "Edit measurement".
3. Change Weight to `5.3`, submit.

**Expected UI result**
- The `Nov 25, 2026` row now reads `5.3kg`. The form resets back to its blank "Add a
  measurement" state afterward.

**Pass criteria:** editing re-populates the form from the clicked row, and saving updates
that same entry in place rather than creating a new one.

---

### Test 5 — Deleting a measurement removes it after confirmation

**Setup:** continue from Test 4.

**Steps (UI)**
1. Click "Delete" on the `Nov 25, 2026` row.
2. Confirm the browser's confirmation dialog.

**Expected UI result**
- That row disappears; only the `Nov 20, 2026` row remains. The Weight trend chart drops
  back to a single point.

**Pass criteria:** delete is destructive only after an explicit confirmation step, and
removes exactly the clicked entry.

---

### Test 6 — A growth measurement shows up in the Home feed

**Setup:** continue from Test 5. Go to `http://localhost:3000/` (the Home feed).

**Steps (UI)**
1. Look at the activity list.

**Expected UI result**
- A row for Riley shows a ruler icon (📏), "4.2kg · 55cm" (the remaining `Nov 20, 2026`
  entry's weight and height — the `Nov 25` row was removed in Test 5), and a relative time
  ("X ago") based on that entry's date.
- The row sits in the same chronological list as diaper/bottle/breastfeeding entries, not
  a separate section.

**Pass criteria:** growth measurements are first-class activity, visible from the same
feed a parent already checks for everything else — not something only reachable from the
Growth page itself.

---

### Test 7 — The Growth page's own "Export PDF" button downloads a growth-only PDF

**Setup:** continue from Test 6. Go back to `http://localhost:3000/growth`.

**Steps (UI)**
1. Click "Export PDF" near the top of the page.

**Expected UI result**
- The button briefly reads "Exporting…", then a file downloads named something like
  `babycheck-riley-growth.pdf`.
- Opening it shows: a "Growth Measurements" heading, "Riley", a "Weight trend" chart and a
  "Height trend" chart (each with the one remaining data point), and a Date/Weight/Height
  table below them — no diaper/bottle/breastfeeding content, no app chrome, no theme
  color. This is a separate PDF from the Step 12 export, not a section added to it.

**Pass criteria:** growth has its own export, scoped to growth data only, matching the
roadmap note that this exports "alongside" the existing charts rather than merged into
them — and since the Growth page has no date-range picker, the PDF always reflects the
baby's full history, not a selected window.

---

### Test 8 — The page is written in whichever language is currently selected

**Setup:** continue from Test 7. Click "PT" in the language switcher (top bar).

**Steps (UI)**
1. Look at the page.

**Expected UI result**
- The heading reads "Medidas de crescimento", the weight field label reads "Peso (Kg)"
  (capital K, per the design note), the height field reads "Altura (cm)", and the
  remaining history row reads `4.2Kg` (capital K) instead of `4.2kg`.
- Switch back to "EN" before continuing to the next test.

**Pass criteria:** switching language changes the unit labels' capitalization/wording,
never the stored value — the measurement itself is unaffected.

---

## Negative / edge cases

### Test 9 — Submitting with neither weight nor height is rejected inline

**Setup:** continue from Test 8 (back in English).

**Steps (UI)**
1. Leave both Weight and Height blank, set a Date, submit.

**Expected UI result**
- An inline red error appears under the Weight field ("enter a weight or a height"). No
  new row is added to the history list.

**Pass criteria:** an entry that's neither a weight nor a height measurement is rejected
server-side, not silently accepted as an empty row.

---

### Test 10 — Growth measurements are scoped to the active baby only

**Setup:** continue from Test 9. Add a second baby from the baby switcher — Name `Sam`,
any swatch — and go to `/growth` while Sam is active.

**Steps (UI)**
1. Confirm the Growth page is empty for Sam (Riley's `Nov 20, 2026` entry doesn't show).
2. Add a measurement for Sam: Weight `3.8`, Date `2026-11-26`.
3. Switch the active baby back to Riley and reload `/growth`.

**Expected UI result**
- Step 1: Sam's page starts empty, independent of Riley's existing entry.
- Step 3: Riley's page shows only Riley's `Nov 20, 2026` entry — Sam's measurement never
  appears there.

**Pass criteria:** the history list, charts, and form are always scoped to whichever
baby is currently active, the same way every other per-baby page works.

---

### Test 11 — The growth measurements endpoint requires authentication

**Setup:** none needed beyond a baby existing — this test bypasses the UI entirely.

**Steps (API)**
```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000/api/babies/1/growth_measurements
```

**Expected result**
- `401`.

**Pass criteria:** growth measurements are gated by the same authentication every other
per-baby endpoint uses.

---

### Test 12 — The growth export endpoint also requires authentication

**Setup:** none needed beyond a baby existing — this test bypasses the UI entirely.

**Steps (API)**
```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000/api/babies/1/growth_measurements/export
```

**Expected result**
- `401`.

**Pass criteria:** the dedicated growth PDF export is gated the same way as every other
per-baby endpoint — it isn't an accidentally-public URL just because it's a newer route.

---

### Test 13 — A non-positive weight or height is rejected (backend check)

**Setup:** get a bearer token (see [Before you start](#before-you-start)) and a baby id
(check the `/api/babies` response, or the UI's URL/network tab).

**Steps (API)**
```
curl -s -X POST http://localhost:4000/api/babies/<baby_id>/growth_measurements \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"weight_kg": -1, "measured_at": "2026-11-20"}'
```

**Expected result**
- `422` with a `weight_kg` error reading `["must be greater than 0"]`.

**Pass criteria:** the "greater than 0" constraint is enforced server-side, not only by
the HTML `min="0"` attribute on the form inputs.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Growth page, no entries | Add-measurement form shown; empty state, no charts |
| 2 | Add weight + height together | History row, both trend charts, correct year group |
| 3 | Add weight-only entry | Row shows weight only; only the weight chart gains a point |
| 4 | Edit an entry | Form pre-fills; saving updates that row in place |
| 5 | Delete an entry (confirmed) | Row and its chart point are removed |
| 6 | Check the Home feed | Growth measurement appears there, icon + weight/height |
| 7 | Click "Export PDF" on the Growth page | Downloads a separate, growth-only PDF |
| 8 | Switch language to PT | Labels and values use "Kg"/"cm" wording for pt-BR |
| 9 | Submit with neither value | Rejected inline, no row added |
| 10 | Two babies, each logs independently | Growth data never crosses between babies |
| 11 | `curl` the measurements endpoint with no token | `401` |
| 12 | `curl` the growth export endpoint with no token | `401` |
| 13 | `curl` a negative weight | `422`, `must be greater than 0` |

If every row holds, Step 13 delivers what the roadmap asks for: a parent can track a
baby's growth over time and bring that history to a pediatrician appointment, the same
way Step 12 already does for the other three metrics.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
