# Manual Test Plan — Step 12: Share / Export Log Summary

Scope: [roadmap.md](../base_content/roadmap.md) Step 12 — an "Export PDF" action on the
Charts page that renders a plain, printable one-pager per baby: a totals table for the
currently selected date range, followed by the same three Step 7 charts (diaper / bottle /
breastfeeding) as grayscale bar charts — no app chrome, no theme color, since the PDF is
meant to be read on paper, handed to a pediatrician.

**Scope note:** the PDF always reflects whichever date range (Today / 7 days / 30 days /
Custom) is currently selected on the Charts page — there's no separate range picker inside
the export flow itself.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
- Any browser works for the UI tests below (no DevTools emulation needed this time); a
  couple of edge-case tests call the API directly with `curl`.
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
5. Quick-log one of each: tap the diaper, bottle, and breastfeeding buttons once each.
6. Go to `http://localhost:3000/charts`.

---

## Positive cases

### Test 1 — The Charts page has an "Export PDF" button

**Setup:** continue right after the setup above, on the Charts page, "7 days" selected
(the default).

**Steps (UI)**
1. Look below the date-range controls.

**Expected UI result**
- An "Export PDF" button is visible, below the preset tabs / custom-range inputs and above
  the three chart cards.

**Pass criteria:** the export action is reachable from the same page as the charts it
summarizes, reusing that page's own date-range control (nothing new to configure).

---

### Test 2 — Clicking it downloads a real PDF

**Setup:** continue from Test 1.

**Steps (UI)**
1. Click "Export PDF".

**Expected UI result**
- The button's label briefly changes to "Exporting…", then a file download starts (named
  something like `babycheck-riley-summary.pdf`).
- Opening the downloaded file (in a PDF viewer, or your browser's own) shows a plain white
  page: a heading ("BabyCheck Summary"), a line with "Riley" and the date range, a totals
  table (Diaper / Bottle / Breastfeeding, each with a count of at least 1 from the setup
  step), and three labeled bar charts below it, in shades of gray — no pink/teal accent
  color anywhere, no app navigation chrome. Each chart has dashed horizontal gridlines with
  a number label on the left (e.g. "2", "4", "6"), so a bar's value is readable without
  guessing from its height alone.

**Pass criteria:** matches the roadmap's design note exactly — a plain, printable one-pager,
not a screenshot of the on-screen charts.

---

### Test 3 — The PDF is written in whichever language is currently selected

**Setup:** continue from Test 2. Click "PT" in the language switcher (top bar).

**Steps (UI)**
1. Click "Exportar PDF" (the button's own label switches too).

**Expected UI result**
- The newly downloaded PDF opens showing "Resumo do BabyCheck" instead of "BabyCheck
  Summary", the totals table reading "Fralda" / "Mamadeira" / "Amamentação", and the date
  range written day-first (e.g. `20/11/2026` rather than `11/20/2026`) — matching how dates
  are written everywhere else in the pt-BR UI.
- Switch back to "EN" before continuing to the next test.

**Pass criteria:** the PDF is rendered server-side with no session locale of its own, so it
has to pick up whichever language the Vue app currently has active and render fully in
that language — not always English regardless of the UI.

---

### Test 4 — The PDF reflects whichever range is currently selected

**Setup:** continue from Test 3 — click "EN" in the language switcher first, to go back to
English for the rest of these tests.

**Steps (UI)**
1. Click "30 days" in the preset tabs.
2. Click "Export PDF" again.

**Expected UI result**
- The newly downloaded PDF's date-range line now shows a 30-day span instead of 7, and its
  bar charts show 30 days' worth of (mostly empty) bars instead of 7.

**Pass criteria:** the export always matches the on-screen range at the moment it's
clicked — there's no separate, independent range state for the export itself.

---

### Test 5 — A Custom range exports correctly

**Setup:** continue from Test 4.

**Steps (UI)**
1. Click "Custom". Set both date inputs to today's date.
2. Click "Export PDF".

**Expected UI result**
- The PDF's date-range line shows today's date on both ends, and the totals table matches
  exactly what's on screen for that single day.

**Pass criteria:** the custom range control (reused from Step 7) flows through to the
export unchanged.

---

## Edge cases

### Test 6 — Exporting with zero logs in range still produces a valid PDF

**Setup:** continue from Test 5. Click "Today", then set a Custom range far in the past
(e.g. a year ago) where nothing was ever logged.

**Steps (UI)**
1. Click "Export PDF".

**Expected UI result**
- The download still succeeds. The PDF opens normally: totals table shows 0 for all three
  metrics, and each chart renders its empty day-axis with no bars (no crash, no broken
  layout, no error toast).

**Pass criteria:** an all-zero range is a normal case, not an error — nothing in the PDF
layout assumes at least one logged entry exists.

---

### Test 7 — Exporting only ever includes the active baby

**Setup:** continue from Test 6. Add a second baby from the baby switcher — Name `Sam`,
any swatch — and quick-log one diaper change for Sam. Switch back to Riley, go to Charts,
set the range back to "7 days".

**Steps (UI)**
1. Click "Export PDF" while Riley is the active baby.

**Expected UI result**
- The PDF's header reads "Riley", and its totals match only Riley's logs — Sam's diaper
  change does not add to Riley's count.

**Steps (UI, continued)**
2. Switch the active baby to Sam (baby switcher) and click "Export PDF" again.

**Expected UI result**
- This second PDF's header reads "Sam", with Sam's own totals.

**Pass criteria:** the export is always scoped to whichever baby is currently active, the
same way the on-screen charts are.

---

### Test 8 — The export endpoint requires authentication

**Setup:** none needed beyond a baby existing — this test bypasses the UI entirely.

**Steps (API)**
```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000/api/babies/1/export
```

**Expected result**
- `401`.

**Pass criteria:** the PDF export is gated by the same authentication every other
per-baby endpoint uses — it's not an accidentally-public URL.

---

### Test 9 — The downloaded file is a well-formed PDF (backend check)

**Setup:** get a bearer token (see [Before you start](#before-you-start)) and a baby id
(check the `/api/babies` response, or the UI's URL/network tab).

**Steps (API)**
```
curl -s -H "Authorization: Bearer <token>" \
  "http://localhost:4000/api/babies/<baby_id>/export?from=2026-11-20T00:00:00Z&to=2026-11-26T23:59:59Z" \
  -o /tmp/summary.pdf

file /tmp/summary.pdf
```

**Expected result**
- `file` reports `PDF document, version 1.7` (or similar) — a genuinely valid PDF, not an
  error page or empty body.

**Pass criteria:** confirms the PDF generation itself (not just the browser-side download
plumbing) produces a real, openable file.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Charts page | "Export PDF" button is visible |
| 2 | Click Export PDF | A real, plain (no chrome/theme color) PDF downloads |
| 3 | Switch language to PT, export | PDF text and date format are in pt-BR, not English |
| 4 | Change preset range, export again | PDF reflects the new range |
| 5 | Custom range, export | PDF matches the custom range exactly |
| 6 | Export a range with zero logs | Still a valid PDF, totals all 0, no crash |
| 7 | Export for each of two babies | Each PDF only contains that baby's own data |
| 8 | `curl` the export endpoint with no token | `401` |
| 9 | `curl` the export endpoint with a token, inspect with `file` | Valid PDF document |

If every row holds, Step 12 delivers what the roadmap asks for: the data collected for its
own sake becomes something a parent can actually hand to a doctor.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
