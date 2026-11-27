# Manual Test Plan — Step 10: Installable, Offline-Capable App (PWA)

Scope: [roadmap.md](../base_content/roadmap.md) Step 10 — making the Vue app installable to
a phone's home screen, and making quick-logging (the one-tap diaper/bottle/breastfeeding
buttons) keep working with no network connection, syncing automatically once back online.

**Scope note, mirroring Step 9's own:** this step makes the app shell load offline and the
quick-log *write* path resilient via an IndexedDB-backed outbox — it does **not** cache API
`GET` responses for general offline reading. A log-list page opened for the first time while
offline will show nothing from the server (though anything still queued from the outbox still
appears, dashed-border and all — that's Test 6 below). Re-opening a page you'd already loaded
once while online works, since the app shell itself is precached by the service worker.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- Use **Chrome** for every UI test below — DevTools' Network "Offline" throttle preset and
  the Application tab's PWA inspection are what these tests rely on to simulate connectivity
  loss deterministically; Mailpit isn't needed (nothing here sends email).
- **Start from an empty database.** This file assumes zero users, babies, and logs before
  Test 1. If you're re-running this file, empty it first with the snippet below (the same
  one this file's [Cleanup](#cleanup) section ends with).
- A couple of tests confirm server-side state directly, via `docker compose exec api iex -S mix`
  with:
  ```elixir
  alias Api.Repo
  alias Api.DiaperLogs
  alias Api.DiaperLogs.DiaperLog
  ```
- A couple of tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering. Get a bearer token the same way the UI does:
  ```
  curl -s -X POST http://localhost:4000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"<email>","password":"<password>"}'
  ```
  The response body's `data.access_token` is your bearer token.

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
4. Go to `http://localhost:3000/` (the home feed) and leave it open — this first, online
   visit is what lets the service worker precache the app shell for Test 2.

---

## Positive cases

### Test 1 — The app is installable

**Setup:** continue right after the setup above, still online.

**Steps (UI)**
1. Open Chrome DevTools → Application tab → Manifest.
2. Separately, look at the address bar for an install icon (desktop Chrome shows a small
   install/monitor icon on the right side of the address bar once a page qualifies).

**Expected UI result**
- The Manifest panel shows name "BabyCheck", short name "BabyCheck", theme color
  `#7FB7BE`, background color `#FFF9F4`, display "standalone", and three icons (192×192,
  512×512, and a 512×512 one flagged "Maskable") — with no installability errors listed
  at the top of the panel.
- Application → Service Workers shows one activated, running service worker for
  `localhost:3000`.
- The address bar's install icon may **not** appear on a first visit even though the app
  is fully installable — Chrome gates that icon (and the `beforeinstallprompt` event
  behind it) on its own site-engagement heuristic, which only builds up from real,
  repeated visits, separate from technical installability. Don't treat a missing icon on
  a fresh profile as a failure; the Manifest panel's lack of errors is the real signal.
  To see the install prompt immediately for testing, enable
  `chrome://flags/#bypass-app-banner-engagement-checks` and restart Chrome, then reload —
  the install icon and clicking-it-installs-BabyCheck flow is Chrome's own standard UI;
  nothing here is custom-built.

**Pass criteria:** the manifest and an activated service worker both exist and satisfy
Chrome's own installability criteria (no errors in the Manifest panel) — no custom "Add
to Home Screen" UI needed, per the roadmap's "Standard install prompt" design note.

---

### Test 2 — The app shell still loads with no network at all

**Setup:** continue from Test 1. The home feed must have been opened at least once while
online already (done above), so the service worker has had a chance to precache it.

**Steps (UI)**
1. In DevTools → Network tab, set the throttling preset to **Offline**.
2. Reload the page (`http://localhost:3000/`).

**Expected UI result**
- The page still renders — the stat strip, the quick-log bar, and the nav are all visible,
  styled correctly (no blank white screen, no browser-native "no internet" error page).
  Any data that would normally come from the API (the feed list, the stat chips) may be
  empty, since that's a live network read, not something the service worker caches — see
  this file's scope note above.

**Pass criteria:** the app shell itself (HTML/CSS/JS) loads fully offline, which is the
precondition for quick-logging to work at all with no connection — if the shell itself
couldn't load, there'd be nothing to tap.

---

### Test 3 — A quick-log tap while offline queues instantly, with a visible "still syncing" cue

**Setup:** continue from Test 2 — still on `http://localhost:3000/`, Network still set to
**Offline**.

**Steps (UI)**
1. Notice the thin cream banner at the top of the app reading "Offline — logs will sync
   when you're back online."
2. Tap the diaper button (🧷) in the global quick-log bar.

**Expected UI result**
- The quick-log bar behaves exactly as it does online — the Nightlight Glow pulses, a
  vibration fires (if supported), and the "Diaper logged · Undo" toast appears instantly.
  Nothing hangs or shows an error.
- Navigate to the dedicated diaper log page (🧷 in the nav). The new entry appears with a
  **dashed border** around its row — distinct from the brief, solid-but-dimmed look a
  normal in-flight tap has online, since this one genuinely has nowhere to go yet.

**Pass criteria:** offline quick-logging feels identical to online quick-logging from the
tapper's perspective — the dashed border is the only hint anything is different, matching
the roadmap's "ambient, not an alert" design intent.

---

### Test 4 — Going back online syncs automatically, no manual action

**Setup:** continue from Test 3 (one dashed-border diaper entry queued, still offline).

**Steps (UI)**
1. In DevTools → Network, switch the throttling preset back to **No throttling** (or
   **Online**).
2. Wait a few seconds without touching anything.

**Expected UI result**
- The offline banner disappears.
- The diaper log row's dashed border disappears on its own — it becomes a normal,
  confirmed row — with no page reload and no further tap required.

**Backend verification**
```elixir
baby = Repo.one(Api.Babies.Baby)
DiaperLogs.list_logs(baby) |> length()
# => 1 (the offline tap became exactly one real row, not zero and not duplicated)
```

**Pass criteria:** reconnecting is entirely passive from the user's side — the queued log
syncs in the background and the UI reflects it live, the same way Step 9's insight chips
are "as live as the time-since-last text they sit next to."

---

### Test 5 — Undo on a still-queued entry never touches the network

**Setup:** continue from Test 4's state, Network throttling set back to **Offline**.

**Steps (UI)**
1. Tap the breastfeeding button (🤱).
2. Immediately tap "Undo" on the toast, before switching connectivity back.

**Expected UI result**
- The entry disappears from the breastfeeding log page immediately — Undo doesn't hang or
  wait for connectivity, since there's nothing queued left to send.

**Backend verification** — after switching Network back to **No throttling**:
```elixir
baby = Repo.one(Api.Babies.Baby)
Api.BreastfeedingLogs.list_logs(baby) |> length()
# => 0 (the undone tap never reached the server at all, not created-then-deleted)
```

**Pass criteria:** cancelling a queued tap is instant and leaves no trace server-side —
it's a true cancel, not a race against a create that was already in flight.

---

### Test 6 — A reload while still offline doesn't make a queued log look lost

**Setup:** reset to a clean queued state: with Network **Offline**, tap the bottle button
(🍼) once on the home feed. Confirm its feed row shows the dashed border.

**Steps (UI)**
1. While still offline, reload the page (F5 / Cmd+R).

**Expected UI result**
- After the reload, the bottle entry's dashed-border row is still visible on the home feed
  (and on the dedicated bottle-feeding page) — reloading didn't make it vanish, even though
  the in-memory state from before the reload is gone.

**Steps (UI, continued)**
2. Switch Network back to **No throttling** and wait a few seconds.

**Expected UI result**
- The dashed border disappears once synced, exactly as in Test 4.

**Pass criteria:** the outbox is durable (IndexedDB), not just an in-memory convenience —
a reload at the worst possible moment (still offline) never makes a safely-queued log look
silently lost.

---

### Test 7 — A retried create (e.g. a lost response) doesn't duplicate the log

This is the backend guarantee the offline outbox leans on: if a create request's response
never arrives (connection drop right after the server saved it), the outbox retries the
same request — this proves that retry is safe.

**Steps**
```
TOKEN="<bearer token from the login above>"
BABY_ID=1

curl -s -X POST http://localhost:4000/api/babies/$BABY_ID/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"logged_at":"2026-11-27T09:00:00Z","client_request_id":"retry-test-1"}'

curl -s -X POST http://localhost:4000/api/babies/$BABY_ID/diaper_logs \
  -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
  -d '{"logged_at":"2026-11-27T09:00:00Z","client_request_id":"retry-test-1"}'
```

**Expected result:** both calls return `201` with the **same** `"id"` in `data`.

**Backend verification**
```elixir
import Ecto.Query
Repo.aggregate(from(l in DiaperLog, where: l.client_request_id == "retry-test-1"), :count)
# => 1
```

**Pass criteria:** the same `client_request_id` posted twice (exactly what the outbox does
when it can't tell whether an earlier attempt actually landed) never creates a second row.

---

## Edge cases

### Test 8 — A different account's queued logs are never sent, and never leak

**Setup:** with Network **Offline**, tap the diaper button once (queues a log for Riley,
under `parent@example.com`'s session). Switch Network back to **No throttling**, then
immediately log out and log in as a **different** account (sign up a second one, e.g.
`other@example.com`, with its own baby) before the queued entry has had a chance to sync.

**Expected UI result**
- The second account never sees Riley's queued entry anywhere (not on its own feed, not
  attached to its own baby).

**Steps (continued)**
1. Log back out, log back in as `parent@example.com`.

**Expected UI result**
- Riley's diaper log (queued back in the first session) is now present, synced
  automatically — nothing was lost, it just waited for the right account to come back.

**Pass criteria:** an outbox entry is only ever sent while the account that owns its baby
is the one logged in — a second account on the same browser can't trigger, see, or lose
another account's queued write.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Manifest + service worker | App satisfies Chrome's install criteria; standard install UI |
| 2 | Reload with Network Offline | App shell still renders fully |
| 3 | Quick-log tap while offline | Instant optimistic UI; dashed-border row |
| 4 | Reconnect | Syncs automatically; dashed border clears with no reload |
| 5 | Undo a queued (not yet sent) entry | Removed instantly; never reaches the server |
| 6 | Reload while still offline | Queued row still visible; still syncs once reconnected |
| 7 | Retried create with the same `client_request_id` | One row, not two |
| 8 | A second account on the same browser | Never sees or triggers another account's queued write |

If every row holds, Step 10 delivers what the roadmap asks for: BabyCheck installs like a
native app, and the core one-tap logging loop keeps working — and keeps its promises —
exactly when conditions are worst.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That leaves
the database empty — schema and containers untouched, zero rows — so the next step's
tests can start from the same clean slate this file assumed at the top.
