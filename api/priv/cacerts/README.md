# Vendored CA certificates

## supabase-root-2021-ca.pem

Supabase's Postgres pooler (`*.pooler.supabase.com`) presents a certificate
chain rooted at Supabase's own private CA, not a publicly-trusted one — a
generic bundle like Mozilla's (e.g. the `castore` package) will never
validate it. This file is that root, so `Api.Repo`'s `ssl_opts` in
[runtime.exs](../../config/runtime.exs) can `verify: :verify_peer` against
it directly instead of disabling verification.

Fetched directly from the pooler's own TLS handshake:

```
openssl s_client -starttls postgres \
  -connect aws-0-us-east-2.pooler.supabase.com:5432 -showcerts </dev/null \
  | openssl x509 -outform PEM
```

(the chain returned is leaf → intermediate → root; this file is the root —
subject and issuer both `Supabase Root 2021 CA`, self-signed.)

If a production deploy ever starts failing again with a TLS `unknown_ca`
alert against Supabase, re-run the command above and diff the result
against this file — Supabase may have rotated their CA.
