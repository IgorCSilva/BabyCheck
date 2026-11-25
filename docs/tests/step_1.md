# Manual Test Plan — Step 1: User Accounts

Scope: [roadmap.md](../base_content/roadmap.md) Step 1 — sign up, log in, log out,
"Remember me", and password reset. There's no babies/logging UI yet (that's Steps 2+),
so every test below is scoped entirely to the account lifecycle: the Vue app at
`http://localhost:3000` and the Phoenix API at `http://localhost:4000`.

Unlike a typical first-step account flow, **registration logs you straight in** — there
is no "check your email to confirm your account" gate. If a test below doesn't mention
enabling/confirming an account, that's not an oversight — it genuinely isn't needed here.

## Before you start

- Bring up the stack from the repo root: `docker compose up -d`.
- Services you'll use directly:
  - Vue app — `http://localhost:3000`
  - Phoenix API — `http://localhost:4000`
  - **Mailpit** (catches every email the dev environment sends — this is where
    password-reset links actually show up) — `http://localhost:8025`
  - Adminer (optional, for a visual peek at the DB) — `http://localhost:8081`
- **Start from an empty database.** This file assumes zero users before Test 1 — a
  fresh dev environment already satisfies that. If you're re-running this file, empty
  it first with the snippet below (the same one this file's [Cleanup](#cleanup) section
  ends with).
- All DB verification below uses `docker compose exec api iex -S mix` — never `psql`
  directly — with:
  ```elixir
  alias Api.Repo
  alias Api.Accounts.User
  alias Api.Accounts.UserToken
  import Ecto.Query
  ```
- A few tests call the API directly with `curl`, to reach states the UI's own guards
  prevent you from triggering (a missing bearer token, a stale cookie, etc.). Where a
  test needs a token/cookie, get it the same way the UI does:
  ```
  curl -s -i -c /tmp/bc_cookies.txt -X POST http://localhost:4000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"<email>","password":"<password>"}'
  ```
  The response body's `data.access_token` is your bearer token; `/tmp/bc_cookies.txt`
  (via curl's `-c`/`-b` flags) holds the `refresh_token` cookie for later `curl` calls.

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

---

## Positive cases

### Test 1 — Signing up creates an account and logs you straight in

**Steps (UI)**
1. Open `http://localhost:3000/signup`.
2. Fill in Email `parent@example.com`, Password `supersecret123`, Confirm password
   `supersecret123`.
3. Submit.

**Expected UI result**
- The button briefly reads "Creating account…" (disabled), then you land on `/` showing
  "Welcome, parent@example.com" and a "Log out" button — no separate login step.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
user.email            # => "parent@example.com"
user.hashed_password  # => a long bcrypt hash, not "supersecret123"
Bcrypt.verify_pass("supersecret123", user.hashed_password)  # => true

Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh_token"), :count)
# => 1 (the session created on signup)
```
**Pass criteria:** exactly one user row, with a hashed (not plaintext) password, and
exactly one refresh-token row backing the session the UI just landed you in.

---

### Test 2 — Logging out ends the session, both client- and server-side

**Setup:** continue from Test 1 (logged in).

**Steps (UI)**
1. On the home page, click "Log out".

**Expected UI result**
- You're redirected to `/login`.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh_token"), :count)
# => 0
```
**Pass criteria:** the refresh-token row created at signup is gone — logout actually
revokes the session server-side, not just forgetting the token client-side.

---

### Test 3 — Logging back in works with the password you set

**Setup:** continue from Test 2 (logged out).

**Steps (UI)**
1. On `/login`, enter `parent@example.com` / `supersecret123` and submit.

**Expected UI result**
- Redirected to `/`, showing "Welcome, parent@example.com" again.

**Pass criteria:** the account created in Test 1 can be logged into independently of the
signup flow.

---

### Test 4 — A reloaded page resumes the session instead of bouncing to login

**Setup:** continue from Test 3 (logged in).

**Steps (UI)**
1. Reload the browser tab (F5 / Cmd+R) while on `/`.

**Expected UI result**
- The page briefly shows nothing, then renders the home page again — you are **not**
  sent to `/login`. (Under the hood, the app silently calls `/api/auth/refresh` using the
  `refresh_token` cookie before deciding which page to show.)

**Pass criteria:** a page reload doesn't require logging in again — the access token is
only ever held in memory, but the refresh cookie survives the reload and resumes it.

---

### Test 5 — Forgot password end-to-end, including the email itself

**Setup:** continue from Test 3/4 (doesn't matter if logged in or out).

**Steps (UI)**
1. Go to `/login`, click "Forgot password?".
2. Enter `parent@example.com`, submit.
3. Open Mailpit at `http://localhost:8025` — you should see a new message, subject
   "Reset your BabyCheck password", to `parent@example.com`.
4. Open it and copy the reset link (it looks like
   `http://localhost:3000/reset-password/<long token>`).
5. Visit that link directly in the browser.
6. Enter a new password `newpassword456` twice, submit.

**Expected UI result**
- Step 2: the forgot-password page shows a generic success message ("If an account
  exists for that email, we've sent instructions…") regardless of what you typed.
- Step 6: you land on `/` already logged in — no separate login step after resetting.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
Bcrypt.verify_pass("newpassword456", user.hashed_password)  # => true
Bcrypt.verify_pass("supersecret123", user.hashed_password)  # => false
```
**Pass criteria:** the password is genuinely changed, the old one stops working, and the
reset itself logs you in without a separate manual login.

---

## Negative cases

### Test 6 — Wrong password (and unknown email) show the same generic error

**Steps (UI)**
1. Log out if needed. On `/login`, enter `parent@example.com` with a wrong password
   (e.g. `wrongpassword`). Submit.
2. Then try an email that was never registered, e.g. `nobody@example.com`, with any
   password. Submit.

**Expected UI result**
- Both attempts show the exact same red banner: "invalid email or password" — nothing
  distinguishes "wrong password for a real account" from "no such account".

**Pass criteria:** the error message can't be used to discover which emails are
registered.

---

### Test 7 — Signing up with an email already in use is rejected inline

**Steps (UI)**
1. Go to `/signup` and submit `parent@example.com` again (any password).

**Expected UI result**
- The form stays on `/signup`. Under the Email field, a red line reads "has already
  been taken" — there is **no** generic red banner above the form for this case (field
  errors render inline per-field; the banner only appears for non-field errors).

**Backend verification**
```elixir
Repo.aggregate(from(u in User, where: u.email == "parent@example.com"), :count)
# => 1 (the second attempt never inserted a row)
```
**Pass criteria:** exactly one row for that email — the duplicate attempt is rejected
before insert, not merged or overwritten.

---

### Test 8 — A too-short password is rejected inline

**Steps (UI)**
1. At `/signup`, use a fresh email, password `short12` (7 chars) in both password
   fields.

**Expected UI result**
- Inline error under Password: "should be at least 8 character(s)". No account created.

**Pass criteria:** the 8-character minimum is enforced server-side (this is submitted to
the API — the HTML input has no `minlength` to catch it client-side first).

---

### Test 9 — Mismatched password confirmation is rejected inline

**Steps (UI)**
1. At `/signup`, use a fresh email, Password `supersecret123`, Confirm password
   `somethingelse`.

**Expected UI result**
- Inline error under Confirm password: "does not match password". No account created.

---

### Test 10 — A malformed email is rejected inline

**Steps (UI)**
1. At `/signup`, enter `not-an-email` in the Email field (note: the input is
   `type="email"`, so some browsers may block this before it's even sent — if yours
   does, confirm the server-side rule directly instead):
   ```
   curl -s -X POST http://localhost:4000/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"not-an-email","password":"supersecret123","password_confirmation":"supersecret123"}'
   ```

**Expected result**
- `422` with `{"errors":{"email":["must be a valid email"]}}` (or the equivalent inline
  field error in the UI, if your browser let the submission through).

**Backend verification**
```elixir
Repo.aggregate(from(u in User, where: u.email == "not-an-email"), :count)
# => 0
```
**Pass criteria:** the email-format rule is enforced by the API itself, not only by the
browser's own `type="email"` check.

---

## Validation / edge cases

### Test 11 — Email is case-insensitive for both signup and login

**Steps (UI)**
1. Sign up with `Mixed.Case@Example.com` / `supersecret123`.
2. Log out.
3. Log back in using `mixed.case@EXAMPLE.com` (different casing) / `supersecret123`.

**Expected UI result**
- Step 3 logs in successfully, landing on the same account from step 1.

**Backend verification**
```elixir
Repo.aggregate(from(u in User, where: u.email == "mixed.case@example.com"), :count)
# => 1 (stored lowercase, regardless of how it was typed)
```
**Pass criteria:** exactly one row, stored lowercase; login matches regardless of the
casing used at the login screen.

---

### Test 12 — Requesting a reset for an unknown email looks identical, and sends nothing

**Steps (UI)**
1. On `/forgot-password`, submit an email that was never registered, e.g.
   `ghost@example.com`.

**Expected UI result**
- The exact same generic success message as Test 5 — no indication the email doesn't
  exist.

**Backend verification**
- Open Mailpit (`http://localhost:8025`) — confirm **no** new message was sent to
  `ghost@example.com`.

**Pass criteria:** the UI response is indistinguishable from the real case in Test 5,
but no email actually goes out for an account that doesn't exist.

---

### Test 13 — An invalid/already-used reset token is rejected, with a way forward

**Setup:** continue from Test 5 (a password was already reset using that token).

**Steps (UI)**
1. Visit the **same** reset link from Test 5 again (now already used once).
2. Also try a clearly made-up one: `http://localhost:3000/reset-password/not-a-real-token`.

**Expected UI result**
- Both show a red error alongside the message and a "Request a new link" link back to
  `/forgot-password`. No password is changed.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
Bcrypt.verify_pass("newpassword456", user.hashed_password)  # still => true, unchanged
```
**Pass criteria:** a reset token can't be replayed after use, and a nonsense token is
rejected the same way — neither changes the password.

---

## Security / session cases

### Test 14 — Visiting the home page while logged out redirects to login

**Steps**
1. Open a private/incognito window (guaranteed no cookies) and go to
   `http://localhost:3000/`.

**Expected UI result**
- You're redirected to `/login?redirect=/` before any home-page content ever appears.

**Pass criteria:** the route guard blocks access client-side; there's no flash of the
authenticated home page first.

---

### Test 15 — Visiting login/signup while already logged in redirects home

**Setup:** log in via the UI.

**Steps**
1. While logged in, manually navigate to `http://localhost:3000/login` (type it in the
   address bar).

**Expected UI result**
- You're immediately redirected to `/` — the login form never shows.

**Pass criteria:** an authenticated session can't re-reach the login/signup screens.

---

### Test 16 — Calling a protected endpoint with no token is rejected

**Steps**
```
curl -s -i http://localhost:4000/api/me
```

**Expected result**
- `401` with `{"errors":{"detail":"unauthenticated","code":"unauthenticated"}}`.

**Pass criteria:** the API enforces authentication on its own — this isn't only a
frontend-side gate (Test 14 showed the frontend gate; this proves the backend one).

---

### Test 17 — A revoked (logged-out) refresh token can't be reused

**Steps**
```
# Log in and capture the cookie
curl -s -i -c /tmp/bc_cookies.txt -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"parent@example.com","password":"newpassword456"}'

# Log out (revokes the refresh token server-side)
curl -s -i -b /tmp/bc_cookies.txt -X DELETE http://localhost:4000/api/auth/logout

# Try to refresh using the SAME (now-revoked) cookie file
curl -s -i -b /tmp/bc_cookies.txt -X POST http://localhost:4000/api/auth/refresh
```

**Expected result**
- The final `refresh` call returns `401` with
  `{"errors":{"detail":"invalid or expired session","code":"invalid_session"}}`.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh_token"), :count)
# => 0
```
**Pass criteria:** logging out doesn't just drop the cookie client-side — the token row
backing it is actually deleted, so the old cookie value is permanently useless, even if
an attacker had copied it beforehand.

---

### Test 18 — Refresh rotates the token; the old cookie value stops working

**Steps**
```
curl -s -c /tmp/bc_cookies2.txt -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"parent@example.com","password":"newpassword456"}' > /dev/null

OLD_COOKIE=$(grep refresh_token /tmp/bc_cookies2.txt | awk '{print $7}')

# First refresh: should succeed and rotate the cookie
curl -s -i -b /tmp/bc_cookies2.txt -c /tmp/bc_cookies2.txt -X POST http://localhost:4000/api/auth/refresh

# Manually replay the OLD cookie value a second time
curl -s -i -X POST http://localhost:4000/api/auth/refresh \
  -H "Cookie: refresh_token=$OLD_COOKIE"
```

**Expected result**
- The first refresh returns `200` with a new `access_token` and a new `Set-Cookie`
  value (different from `OLD_COOKIE`).
- The second call (replaying `OLD_COOKIE`) returns `401`
  (`invalid_session`) — a refresh token can only ever be used once.

**Pass criteria:** each refresh rotates the token; a captured old value can't be reused
even a single time after a newer one has been issued.

---

### Test 19 — Resetting your password logs out every other session

Proves a password reset isn't just cosmetic — it actually invalidates sessions that
were already open elsewhere (e.g. a device you lost, or suspect was compromised).

**Setup**
1. Log in via the UI (session A). Leave it open.
2. Separately, via `curl`, log in again as the same user to simulate a second device
   (session B), capturing its cookie:
   ```
   curl -s -c /tmp/bc_session_b.txt -X POST http://localhost:4000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"parent@example.com","password":"newpassword456"}'
   ```

**Steps (UI, session A)**
1. Go to `/forgot-password`, request a reset for `parent@example.com`, grab the link
   from Mailpit, and complete the reset with a new password `yetanotherpass789`.

**Expected result**
- The reset itself succeeds and leaves session A (the browser that performed it) logged
  in, per Test 5.
- Session B's cookie is now dead:
  ```
  curl -s -i -b /tmp/bc_session_b.txt -X POST http://localhost:4000/api/auth/refresh
  ```
  returns `401` / `invalid_session`.

**Backend verification**
```elixir
user = Repo.one(from u in User, where: u.email == "parent@example.com")
Repo.aggregate(from(t in UserToken, where: t.user_id == ^user.id and t.context == "refresh_token"), :count)
# => 1 (only the brand-new session from the reset itself — session B's row is gone)
```
**Pass criteria:** a password reset revokes every previously-issued refresh token for
that user, not just the one used to perform the reset.

---

### Test 20 — "Remember me" controls how long the session cookie lasts

**Steps**
```
# Checked
curl -s -i -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"parent@example.com","password":"yetanotherpass789","remember_me":true}' \
  | grep -i set-cookie

# Unchecked
curl -s -i -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"parent@example.com","password":"yetanotherpass789","remember_me":false}' \
  | grep -i set-cookie
```

**Expected result**
- `remember_me: true` → `Set-Cookie: refresh_token=...; ...; max-age=2592000; ...`
  (30 days).
- `remember_me: false` → `max-age=86400` (1 day).

**Pass criteria:** the two values are different, and match the "Remember me" checkbox's
intent — ticking it isn't cosmetic, it genuinely changes how long the cookie survives.

---

## Summary checklist

| # | Scenario | Expected result |
|---|----------|------------------|
| 1 | Sign up | Account created, logged in immediately, 1 refresh token |
| 2 | Log out | Redirected to login; refresh token revoked server-side |
| 3 | Log back in | Works with the password set at signup |
| 4 | Reload the page | Session resumes silently, no bounce to login |
| 5 | Forgot password, full loop | Email arrives in Mailpit; reset logs you in; old password stops working |
| 6 | Wrong password / unknown email | Identical generic error either way |
| 7 | Duplicate email signup | Rejected inline, no second row |
| 8 | Password < 8 chars | Rejected inline |
| 9 | Password confirmation mismatch | Rejected inline |
| 10 | Malformed email | Rejected server-side (`422`) |
| 11 | Email casing | Case-insensitive on both signup and login; stored lowercase |
| 12 | Reset request for unknown email | Same generic success message; no email sent |
| 13 | Reused/invalid reset token | Rejected, with a link to request a new one |
| 14 | Visit `/` logged out | Client-side redirect to `/login` |
| 15 | Visit `/login` logged in | Client-side redirect to `/` |
| 16 | `/api/me` with no token | `401 unauthenticated` |
| 17 | Reuse a revoked refresh token | `401 invalid_session` |
| 18 | Reuse an already-rotated refresh token | `401 invalid_session` |
| 19 | Password reset vs. other sessions | Every other session's refresh token is revoked |
| 20 | Remember me on/off | Cookie `max-age` is 30 days vs. 1 day |

If every row holds, Step 1's account system is safe to build on: sessions are real
server-side state (not just client-side tokens), passwords are never stored or leaked
in plaintext, and every error message is exactly as specific (or as deliberately vague)
as the design intends.

---

## Cleanup

Run the truncate snippet from
["Resetting the database to empty"](#resetting-the-database-to-empty) above. That
leaves the database empty — schema and containers untouched, zero rows — so Step 2's
tests can start from the same clean slate this file assumed at the top.
