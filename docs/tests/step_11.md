# Manual Test Plan — Step 11: Night Mode

Scope: [roadmap.md](../base_content/roadmap.md) Step 11 — a dark, low-blue-light theme,
switched manually (Light / Dark) or automatically via the OS's own `prefers-color-scheme`
setting (Auto). This is a pure frontend step — no backend change, no new data — so every
test below is scoped entirely to the Vue app at `http://localhost:3000`.

**Scope note:** "automatically by local time" in the roadmap's feature line is satisfied
transitively: the app follows the OS/browser's `prefers-color-scheme`, and most OSes
(macOS, Android, iOS, Windows) offer their own "switch by local time / sunset-sunrise"
dark-mode option. The app itself has no clock-based logic of its own — it only ever reads
the OS's current preference, live.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
- Use **Chrome** for every test below — DevTools' Rendering tab has a direct
  "Emulate CSS media feature `prefers-color-scheme`" control, which is what the Auto-mode
  tests use to simulate an OS-level preference change without actually changing your OS
  settings.
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

---

## Positive cases

### Test 1 — A fresh browser profile defaults to Auto, following the OS preference

**Setup:** continue right after the setup above. Open DevTools → the Rendering tab (⋮ menu
→ More tools → Rendering if it isn't already a tab) → set "Emulate CSS media feature
prefers-color-scheme" to **light**.

**Steps (UI)**
1. Reload the page.
2. Look at the top bar's theme switcher (next to the language switcher): "Light / Dark /
   Auto".

**Expected UI result**
- "Auto" is the active (filled) option — no explicit choice has been made yet.
- The app renders in its light palette: warm cream background, white cards.

**Pass criteria:** with no stored preference, the app follows the OS/browser's current
color scheme rather than defaulting to a fixed light or dark look.

---

### Test 2 — Auto mode tracks a live OS preference change, with no reload

**Setup:** continue from Test 1, still on "Auto".

**Steps (UI)**
1. In DevTools → Rendering, switch "Emulate CSS media feature prefers-color-scheme" to
   **dark**.

**Expected UI result**
- Without reloading or touching anything else, the app immediately switches to the dark
  palette: near-black warm charcoal background, light text, dimmed/desaturated accent
  colors on the quick-log buttons and Riley's avatar (compare to the bright pink swatch
  picked at signup — the avatar should look visibly muted, not the raw bright pink).
- "Auto" is still the active option in the theme switcher (this was a live OS-level
  change, not a manual override).

**Pass criteria:** Auto mode is genuinely live — it reacts to the OS preference changing
while the app is already open, not just at load time.

---

### Test 3 — Manually choosing Dark overrides the OS preference

**Setup:** continue from Test 2. In DevTools → Rendering, set the emulated preference back
to **light** first (so the override is unambiguous).

**Steps (UI)**
1. Click "Dark" in the theme switcher.

**Expected UI result**
- The app switches to the dark palette immediately, even though the emulated OS
  preference is "light". "Dark" is now the active option in the switcher (not "Auto").

**Pass criteria:** a manual choice wins over the OS preference.

---

### Test 4 — A manual choice persists across a reload, and survives the OS preference changing again

**Setup:** continue from Test 3 (manually set to Dark).

**Steps (UI)**
1. Reload the page.

**Expected UI result**
- Still dark, "Dark" still the active switcher option — the choice wasn't forgotten.

**Steps (UI, continued)**
2. In DevTools → Rendering, flip the emulated preference to **dark**, then back to
   **light**, a couple of times.

**Expected UI result**
- The app stays dark throughout — a manual override is not reset or reconsidered by OS
  preference changes; only explicitly clicking a different switcher option changes it.

**Pass criteria:** the manual mode is durable (survives a reload) and exclusive (an OS
preference change never silently overrides it).

---

### Test 5 — Switching back to Light, and back to Auto, both work

**Setup:** continue from Test 4 (manually Dark).

**Steps (UI)**
1. Click "Light" in the theme switcher.

**Expected UI result**
- Immediately back to the light palette; "Light" is the active option.

**Steps (UI, continued)**
2. Click "Auto".

**Expected UI result**
- "Auto" becomes the active option. The palette matches whatever the DevTools-emulated
  `prefers-color-scheme` is currently set to.

**Pass criteria:** all three options are freely selectable and immediately take effect.

---

### Test 6 — Tap targets keep their full size in the dark

**Setup:** switch to Dark (Test 3's steps).

**Steps (UI)**
1. Inspect the three quick-log buttons at the bottom of the screen (diaper / bottle /
   breastfeeding).

**Expected UI result**
- Each button is still the same size as in light mode (56px+), fully legible (white icon
  on the dimmed accent color), and tappable — nothing shrinks or becomes harder to hit.

**Pass criteria:** matches the roadmap's explicit design note — darkness never makes the
core logging buttons harder to use.

---

### Test 7 — Quick-logging works identically in dark mode

**Setup:** continue from Test 6, still Dark.

**Steps (UI)**
1. Tap the diaper quick-log button.

**Expected UI result**
- Behaves exactly as in light mode: the Nightlight Glow pulses (in Riley's dimmed theme
  color), the "Diaper logged · Undo" toast appears, and the entry shows up on the home
  feed and the dedicated diaper log page.

**Pass criteria:** Night Mode is a visual swap only — it doesn't change or break any
existing logging behavior from Steps 3–10.

---

## Edge cases

### Test 8 — The charts page re-colors immediately on a theme switch

**Setup:** log a diaper change or two first (so the chart has data to render), then go to
the Charts page (`http://localhost:3000/charts`) while in Light mode.

**Steps (UI)**
1. Click "Dark" in the theme switcher while still on the Charts page.

**Expected UI result**
- The diaper chart's bars switch from the light-mode sand color to the dark-mode dimmed
  sand color immediately, without needing to navigate away and back or change the date
  range first.

**Pass criteria:** chart colors aren't "stuck" from whatever theme was active when the
page first loaded.

---

### Test 9 — The chosen theme is a browser preference, not tied to one account

**Setup:** continue from Test 8 (Dark mode active).

**Steps (UI)**
1. Log out, then sign up a second account (e.g. `other@example.com`) in the same browser.

**Expected UI result**
- The new account's session also renders in Dark mode — the choice lives in this browser,
  the same way the language choice does, not reset per account.

**Pass criteria:** matches this app's existing convention for device-level UI preferences
(see the language switcher) — no surprise reset on login/logout.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Fresh profile, no stored preference | Defaults to "Auto", follows OS preference |
| 2 | OS preference changes live, while on Auto | App re-themes immediately, no reload |
| 3 | Manually choose Dark | Overrides the OS preference immediately |
| 4 | Reload / OS preference changes again, while manually set | Manual choice persists and isn't overridden |
| 5 | Switch to Light, then to Auto | Both work immediately |
| 6 | Quick-log buttons in Dark | Full size, legible, tappable |
| 7 | Quick-log a diaper change in Dark | Works identically to light mode |
| 8 | Switch theme while Charts page is open | Chart colors update immediately |
| 9 | Switch accounts in the same browser | Theme choice carries over (browser-level, not account-level) |

If every row holds, Step 11 delivers what the roadmap asks for: BabyCheck is comfortable
to use at 3am with the lights off, whether that's because the OS already switched to dark
mode for the night or because the parent chose it themselves — and nothing about the
logging loop itself changes underneath it.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
