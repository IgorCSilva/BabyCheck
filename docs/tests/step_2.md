# Manual Test Plan — Step 2: Baby Profiles

Scope: [roadmap.md](../base_content/roadmap.md) Step 2 — registering one or more babies
under an account, editing/removing them, and switching which one is "active" from a
switcher available everywhere in the app. This builds directly on Step 1
([step_1.md](step_1.md)): every test below assumes a logged-in account already exists.

One architectural point worth keeping in mind while testing: **"active baby" is a
client-side preference, not server state.** It lives in this browser's `localStorage`,
not in the database — nothing in these tests should expect it to follow you to a
different browser or device (Test 11 checks this directly).

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- Mailpit isn't needed for this step — nothing here sends email.
- **Start from an empty database.** This file assumes zero users and zero babies before
  Test 1. If you're re-running this file, empty it first with the snippet below (the
  same one this file's [Cleanup](#cleanup) section ends with).
- All DB verification below uses `docker compose exec api iex -S mix` with:
  ```elixir
  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Babies.Baby
  import Ecto.Query
  ```
- A few tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering (no bearer token, another account's baby id, a
  non-numeric id). Get a token the same way the UI does:
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

### Creating the account these tests share

Most tests below continue from one signed-up account. Create it once, via the UI:

1. Open `http://localhost:3000/signup`.
2. Email `parent@example.com`, Password `supersecret123`, Confirm password
   `supersecret123`. Submit.

**Expected result:** you land on `/babies`, not `/`, with a lone "Add a baby" form and no
baby list below it — this is the gate Test 1 checks explicitly.

---

## Positive cases

### Test 1 — A brand new account is gated behind `/babies` until one exists

**Setup:** continue right after signing up above.

**Steps (UI)**
1. Look at the top bar.
2. Try navigating directly to `http://localhost:3000/` (type it in the address bar).

**Expected UI result**
- The top bar's switcher shows a single dashed pill reading "+ Add your first baby"
  instead of any avatar.
- Step 2 bounces you straight back to `/babies` — the home page never renders, because
  every log in later steps is scoped to a baby and none exists yet.

**Backend verification**
```elixir
Repo.aggregate(from(b in Baby), :count)
# => 0
```
**Pass criteria:** zero babies in the database, and the app is unusable beyond `/babies`
until that changes.

---

### Test 2 — Creating the first baby unlocks the app

**Setup:** continue from Test 1, still on `/babies`.

**Steps (UI)**
1. In the "Add a baby" form, type Name `Riley`.
2. Click the first swatch (soft pink).
3. Click "Add baby".
4. Navigate to `http://localhost:3000/`.

**Expected UI result**
- After submitting, "Riley" appears in a list below the form with Edit/Delete links, and
  the form resets to blank/first-swatch for adding another.
- The top bar's switcher now shows one circular avatar: a pink circle with "R" in it.
- Step 4 now succeeds — you land on the home page instead of being bounced back.

**Backend verification**
```elixir
baby = Repo.one(from b in Baby)
baby.name          # => "Riley"
baby.theme_color   # => "#F5A9B8"
baby.user_id       # => the signed-up account's user id
```
**Pass criteria:** exactly one baby row, owned by the current account, with the name and
color chosen in the UI — and the home page is reachable precisely because it now exists.

---

### Test 3 — A second baby is added and both appear in the switcher

**Setup:** continue from Test 2 (on `/`, "Riley" already exists).

**Steps (UI)**
1. Click the small "+" avatar at the end of the switcher (it navigates to `/babies`).
2. Add Name `Sam`, color: the second swatch (soft blue). Submit.

**Expected UI result**
- The babies list below the form now shows both "Riley" and "Sam".
- The top bar's switcher shows two avatars — pink "R", blue "S" — plus the "+" avatar
  after them.

**Backend verification**
```elixir
Repo.all(from b in Baby, order_by: b.inserted_at, select: {b.name, b.theme_color})
# => [{"Riley", "#F5A9B8"}, {"Sam", "#9DC8E8"}]
```
**Pass criteria:** both babies persisted, in creation order, each with its own color.

---

### Test 4 — Switching the active baby updates the switcher, and survives a reload

**Setup:** continue from Test 3 (on `/babies`, both babies exist).

**Steps (UI)**
1. Go to `http://localhost:3000/`.
2. Click the blue "S" avatar (Sam) in the switcher.
3. Reload the page (F5 / Cmd+R).

**Expected UI result**
- Step 2: the "S" avatar visibly lifts slightly with a soft blue glow behind it (the
  Nightlight Glow motif) — "R" loses that treatment.
- Step 3: after reloading, "S" is still the one shown active — the selection wasn't lost.

**Pass criteria:** the active baby is a real, persisted preference (via `localStorage`,
see the note at the top of this file) — not something that resets on every page load.

---

### Test 5 — Editing a baby's name and color updates it everywhere immediately

**Setup:** continue from Test 4.

**Steps (UI)**
1. Go to `/babies`. Click "Edit" next to "Riley".
2. Change the name to `Riley Updated` and pick the third swatch (soft yellow).
3. Submit.

**Expected UI result**
- The form's heading switches to "Edit baby" and its button to "Save changes" while
  editing, with a "Cancel" link beneath it.
- After submitting, the list shows "Riley Updated" with a yellow avatar, and the form
  resets back to "Add a baby".
- Back on `/`, the switcher's first avatar is now yellow with an "R" (still the same
  baby, new color).

**Backend verification**
```elixir
baby = Repo.one(from b in Baby, where: b.name == "Riley Updated")
baby.theme_color  # => "#F5D376"
Repo.aggregate(from(b in Baby), :count)
# => 2 (still two babies — this was an update, not an extra insert)
```
**Pass criteria:** the same row was updated in place; no duplicate baby was created.

---

## Negative cases

### Test 6 — An empty name is rejected inline

**Steps (UI)**
1. On `/babies`, leave Name blank, pick any swatch, submit. (The field has `required`,
   so your browser may block submission before it's even sent — if so, confirm the
   server-side rule directly instead:)
   ```
   curl -s -X POST http://localhost:4000/api/babies \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <token>" \
     -d '{"name":"","theme_color":"#F5A9B8"}'
   ```

**Expected result**
- `422` with `{"errors":{"name":["can't be blank"]}}` (or the equivalent inline field
  error in the UI, if your browser let the submission through).

**Backend verification**
```elixir
Repo.aggregate(from(b in Baby), :count)
# => unchanged from before this test (no row inserted)
```
**Pass criteria:** the "name required" rule is enforced by the API itself, not only by
the form's `required` attribute.

---

### Test 7 — An invalid theme color is rejected

The UI can never actually produce an invalid color (swatches are fixed hex values, and
the native color picker always returns a valid one), so this is checked directly
against the API:

**Steps**
```
curl -s -X POST http://localhost:4000/api/babies \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"Test","theme_color":"not-a-color"}'
```

**Expected result**
- `422` with
  `{"errors":{"theme_color":["must be a hex color like #F5A9B8"]}}`.

**Pass criteria:** the API validates the color format server-side, independent of
whatever the UI happens to allow a user to construct.

---

### Test 8 — One account can't edit or delete another account's baby

**Setup**
1. Sign up a second account (in a private/incognito window, so it doesn't disturb
   session A): `parent2@example.com` / `supersecret123`, then add a baby named `Other`.
2. Back in session A (the original `parent@example.com`), note "Other"'s id:
   ```
   curl -s http://localhost:4000/api/babies -H "Authorization: Bearer <parent2_token>"
   ```

**Steps**
```
# Using parent@example.com's token against parent2's baby id:
curl -s -i -X PUT http://localhost:4000/api/babies/<other_id> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <parent_token>" \
  -d '{"name":"Hijacked"}'

curl -s -i -X DELETE http://localhost:4000/api/babies/<other_id> \
  -H "Authorization: Bearer <parent_token>"
```

**Expected result**
- Both calls return `404` with `{"errors":{"detail":"not found","code":"not_found"}}` —
  not a `403`, so the response doesn't even confirm a baby with that id exists.

**Backend verification**
```elixir
baby = Repo.one(from b in Baby, where: b.name == "Other" or b.name == "Hijacked")
baby.name  # => "Other" (unchanged)
Repo.aggregate(from(b in Baby), :count)
# => unchanged — the DELETE never ran
```
**Pass criteria:** every lookup is scoped by the authenticated user's own id server-side
— ownership can't be bypassed just by guessing or incrementing an id.

---

## Validation / edge cases

### Test 9 — Deleting the last baby re-locks the app behind `/babies`

**Setup:** continue session A from Test 5 (two babies: "Riley Updated", "Sam").

**Steps (UI)**
1. On `/babies`, delete both babies (confirm each browser prompt).
2. Navigate to `http://localhost:3000/`.

**Expected UI result**
- The switcher reverts to the "+ Add your first baby" empty state as each baby is
  removed, ending with zero.
- Step 2 bounces back to `/babies`, exactly like Test 1 — the gate re-applies the moment
  the account has no babies again, it isn't a one-time check.

**Backend verification**
```elixir
Repo.aggregate(from(b in Baby, where: b.user_id == ^user_id), :count)
# => 0 (user_id from the account created at the top of this file)
```
**Pass criteria:** both deletes persisted server-side, and the home-page gate reacts to
the current count, not just whatever it saw on first login.

---

### Test 10 — Deleting the active baby reassigns active to one that remains

**Setup:** add two babies back (`Riley`, soft pink; `Sam`, soft blue). Make "Sam" the
active one (click its avatar on `/`).

**Steps (UI)**
1. Go to `/babies`, delete "Sam" (the currently-active one).
2. Go to `/`.

**Expected UI result**
- "Riley" is now shown as the active avatar (lifted, with its glow) — the app never ends
  up with an active-baby selection pointing at nothing, as long as at least one baby
  still exists.

**Pass criteria:** deleting the active baby doesn't leave the switcher in a broken or
unselected state.

---

### Test 11 — The active baby is local to this browser, not shared account-wide

**Setup:** continue from Test 10 (session A has "Riley" active).

**Steps**
1. Open a **second, separate browser session** for the same account — e.g. a private/
   incognito window — and log in as `parent@example.com` / `supersecret123`.

**Expected result**
- This new session lands on `/` showing "Riley" as active by default (the first baby),
  **regardless of whatever was last clicked active in session A** — there's no shared
  "active baby" state to sync, by design (see the note at the top of this file).

**Pass criteria:** confirms "active baby" really is a client-side/`localStorage`
preference and not a column on the account — two browsers for the same account can
legitimately disagree about which baby is active.

---

## Security / session cases

### Test 12 — Every `/api/babies` endpoint requires authentication

**Steps**
```
curl -s -i http://localhost:4000/api/babies
curl -s -i -X POST http://localhost:4000/api/babies -d '{"name":"x","theme_color":"#F5A9B8"}'
curl -s -i -X PUT http://localhost:4000/api/babies/1 -d '{"name":"x"}'
curl -s -i -X DELETE http://localhost:4000/api/babies/1
```

**Expected result**
- All four return `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`.

**Pass criteria:** the API enforces authentication on every baby-management action on
its own — this isn't only a frontend-side gate.

---

### Test 13 — A non-numeric id is rejected as "not found," not a server error

**Steps**
```
curl -s -i -X PUT http://localhost:4000/api/babies/not-a-number \
  -H "Authorization: Bearer <token>" \
  -d '{"name":"x"}'

curl -s -i -X DELETE http://localhost:4000/api/babies/not-a-number \
  -H "Authorization: Bearer <token>"
```

**Expected result**
- Both return `404` with `{"errors":{"detail":"not found","code":"not_found"}}` — not a
  `500`.

**Pass criteria:** a malformed id is handled gracefully instead of crashing the request
(the kind of input a careless script or a tampered URL might send).

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | New account, zero babies | Gated to `/babies`; empty-state "+ Add your first baby" pill |
| 2 | Create first baby | App unlocks; switcher shows one avatar |
| 3 | Create second baby | Both appear in list and switcher, in creation order |
| 4 | Switch active baby | Glow moves to the clicked avatar; survives a reload |
| 5 | Edit name/color | Updates in place everywhere; no duplicate row |
| 6 | Blank name | Rejected inline / `422` |
| 7 | Invalid theme color | Rejected, `422` |
| 8 | Edit/delete another account's baby | `404` either way, ownership enforced server-side |
| 9 | Delete the last baby | Re-locked behind `/babies` |
| 10 | Delete the active baby | Active reassigns to a remaining baby |
| 11 | Active baby across sessions | Local to the browser, not shared account-wide |
| 12 | `/api/babies` with no token | `401 unauthenticated` on every verb |
| 13 | Non-numeric id | `404 not_found`, not a crash |

If every row holds, Step 2's baby profiles are safe to build logs on top of: ownership
is enforced server-side (not just hidden by the UI), the home-page gate reacts to real
data rather than a one-time check, and the "active baby" concept behaves exactly like
the local, per-browser preference it's designed to be.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That
leaves the database empty — schema and containers untouched, zero rows — so Step 3's
tests can start from the same clean slate this file assumed at the top.
