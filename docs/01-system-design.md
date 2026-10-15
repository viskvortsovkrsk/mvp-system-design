# 01 · System design

```
user    ──► CDN/WAF ──► L4 LB :443 ──► Caddy (every node) ──► landing · web · api · billing
admin   ──► VPN / zero-trust tunnel + SSO ──► SSH · Grafana · CI

api     ──► Postgres (managed, private)
api     ──► object storage (S3 API)
billing ──► api /internal/* (service token)
```

## Rules

- **Modular monolith.** One repo, one Go module, N binaries in `cmd/`, one image. Split out a binary only for different secrets, failure domain or scaling.
- **One owner per table.** Only the owning service reads/writes it; others call the owner.
- **Internal calls:** HTTP/JSON + service token. Never trust identity or tenant headers from the network. `/internal/*` is never routed at the edge.
- **Stateless processes.** Session = signed cookie (Ed25519/RS256); other services verify it with the public key.
- **Postgres is the source of truth.** Cache or queue only on measured need ([02](02-stack.md)).
- **Money/budget invariants inside one DB transaction** (reserve → settle). No sagas.
- **Buy, don't build:** auth, payments, email, LLM. Store opaque provider ids and minimum PII. Erasing personal data: [Data model](#data-model).
- **Every external provider has a `fake`** for dev/test. Dev shortcuts (fake payments, dev login, prompt trace) are fatal at startup when `ENVIRONMENT=prod`; a test proves it.
- **LLM cost ceiling:** reserve before the call, settle after; `max_tokens`; input length cap; per-user hourly/daily caps; prompt caching; tokens and cost logged per call.
- **Stream, never slurp.** Files, feeds, responses are iterators. Peak memory stays flat as input grows (stress test).
- **Config:** env vars. Secrets from files (`X_FILE=/run/secrets/x`). Missing required value → exit at startup.
- **HTTP server:** read/write/idle timeouts, graceful shutdown, `/healthz` (process alive), `/readyz` (dependencies reachable). Each binary has a `-healthcheck` flag that calls its own `/healthz` (no curl in the image).
- **Schema changes:** expand → deploy → contract in a later release. The previous image must run on the new schema.

## Web security

- Session cookie: `Secure; HttpOnly; SameSite=Lax; Path=/`, `__Host-` prefix unless subdomains share it. Expiry inside the signed payload, checked on every request.
- Revocation: the cookie lives 15 min and carries `sid`. Past 5 min, api re-issues it after checking the `sessions` row (owner: api; kept 30 days from last use). An expired cookie goes to api `/auth/refresh`, same check, else sign-in. Logout, ban, role change and erasure delete the row: access ends within 15 min.
- CSRF: the whole mux sits behind Go's `http.CrossOriginProtection` (rejects cross-origin unsafe methods by `Sec-Fetch-Site` / `Origin`). Own other hosts via `AddTrustedOrigin`; bypass only webhooks.

```go
cop := http.NewCrossOriginProtection()
cop.AddInsecureBypassPattern("POST /webhooks/")
srv.Handler = cop.Handler(mux)
```

- Headers: set once in `deploy/Caddyfile`, so every env gets them ([05](05-dev.md)).

```caddyfile
header {
	Strict-Transport-Security "max-age=63072000; includeSubDomains"
	Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
	X-Content-Type-Options nosniff
	Referrer-Policy strict-origin-when-cross-origin
	Permissions-Policy "camera=(), microphone=(), geolocation=()"
	-Server
}
```

- Providers widen only the directives they need, each origin with a `#` comment saying why: login provider → `form-action` (redirects after sign-out are checked too); payment overlay → `script-src`, `frame-src`, `connect-src`; analytics tag ([02](02-stack.md)) → `script-src`, `img-src`, `connect-src`.
- No inline `<script>`, `<style>`, `style=` or `on*=` in templates; CSP blocks them. JS and CSS are files in `static/`.
- Bodies capped with `http.MaxBytesReader` (1 MB default); uploads stream with their own cap.
- Rate limits: login, signup and other unauthenticated writes per IP at the edge (WAF rate rules); costly routes per user in the app (LLM caps above).

## Inbound webhooks

- Route `POST /webhooks/<provider>`: no cookie, no CSRF check; the signature is the auth.
- Verify the provider's signature over the raw body (secret via `*_FILE`), constant-time compare, timestamp within 5 min when sent. Fail → 401, `error_kind=security_violation`.
- Idempotent: insert the provider's event id into `webhook_events` (unique) in the same transaction as its effect. Duplicate → 200, nothing else.
- Slow effect → store the event, answer 200, `cmd/worker` applies it (Postgres queue, [02](02-stack.md)).
- Events repeat and arrive out of order: apply by the object's state (or re-fetch it), never by arrival.
- Tenant comes from our own lookup of the provider's object id, never from the payload. Isolation coverage lists the route as `exempt: signed webhook`.

## Postgres roles

| Role | Used by | Can |
|---|---|---|
| `owner` | `cmd/migrate` only | owns the schema |
| `app` | services | DML on its tables; bound by RLS; owns nothing |
| `readonly` | people, Grafana, agents — over VPN | `SELECT` on every table, all tenants; nothing else |

`readonly`:
- Skips tenant filtering through a policy, not `BYPASSRLS` (most managed Postgres won't grant it). Every RLS table gets `CREATE POLICY readonly_all ON <t> FOR SELECT TO readonly USING (true)` in the migration that enables RLS.
- Owner grants `USAGE` on schemas, `SELECT` on all tables, and default privileges for future tables.
- Also `pg_read_all_stats` (granted by the provider's admin user), to read `pg_stat_statements`.
- Role settings: `default_transaction_read_only = on`, `statement_timeout = '30s'`, `CONNECTION LIMIT 5`.
- Secrets (token hashes, keys) live in their own tables; `REVOKE SELECT` on those.
- Password in the secret manager. Never used by services.

## Tenant isolation (mandatory)

- Every tenant table has `tenant_id` (or `user_id`), `ENABLE` + `FORCE ROW LEVEL SECURITY`. Tenant policies are `TO app`.
- Tx helper sets `SET LOCAL app.tenant_id` from the authenticated caller, never from input.
- Tests, all three:
  1. Catalog: every table with a tenant column has RLS enabled and forced, and the `readonly_all` policy.
  2. Coverage: every route in `main.go` maps to its isolation test or `exempt: <why>`; an unlisted route fails the build.
  3. Per route: tenant A on tenant B's id → same answer as "not found", nothing of B's in the body, no side effect. Disable the check once and watch the test fail.

## Data model

- Keys: natural where one exists (a slug; `(user_id, product_id)` when exactly one row per pair), else `uuidv7()`: time-ordered, so inserts land at the index end. A provider's id is never a key: own column, unique index.
- Time is `timestamptz`. Money is `bigint` minor units + `currency char(3)`; never `float` or `money`.

| Column | Type | Where |
|---|---|---|
| `created_at` | `timestamptz default now()` | every table |
| `updated_at` | `timestamptz` | rows that change; set by `touch_row()` |
| `data_version` | `int` | rows two writers can overwrite: optimistic lock |
| `entity_version` | `int` | rows with a JSON state column: its format version |

- Optimistic lock: the trigger bumps `data_version`; the writer adds `WHERE data_version = $n`; 0 rows → conflict, reload. The app never increments it.
- `entity_version`: code reads each row by its version and converts old formats; old rows always open.

```sql
CREATE FUNCTION touch_row() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  IF to_jsonb(NEW) ? 'data_version' THEN
    NEW.data_version := OLD.data_version + 1;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
-- per table
CREATE TRIGGER orders_touch BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION touch_row();
```

Account erasure: a job, idempotent, retried; done within 30 days of the request (GDPR Art. 12(3)).
1. Request: sessions deleted. Before confirm, show what is lost: purchases, remaining paid time, no refund.
2. Stop renewals at the provider (scheduled cancel).
3. Grace: 14 days. Signing in shows only "Cancel erasure", which resumes renewals. Then cancel what is still active, no refund; wait for the provider's confirming webhook.
4. Delete the user's bucket objects, every version.
5. One transaction: every `pii` column in the user's rows → `NULL`, provider ids (IdP subject, payment customer) → `NULL`, `erased_at = now()`; erasure logged ([07](07-prod.md#backups)). Rows stay: payments, entitlements and counts keep their `user_id`.
6. Delete at providers: IdP user, email contacts, payment customer where the provider allows it.

- `NULL`, never a partial mask (`j***@gmail.com`) or a hash: both still identify.
- Every `text`, `varchar`, `jsonb` and `inet` column of every table has `COMMENT 'pii'` or `COMMENT 'not pii'`; a catalog test fails on one without. User-written text is `pii`. `pii` columns are nullable.
- Not a merchant of record → invoices are ours to keep for the legal term: own table, outside erasure, purged when the term ends.
- Webhook for an erased user → 200, logged, no effect.
- Tenant offboarding: when the contract ends, export on request (rows as JSON, files). 30 days after the end: delete the tenant's bucket objects (every version) and rows; invoices stay per the rule above; logged like an account erasure.
- Soft delete (`deleted_at`) is for non-personal data that must stay visible to existing owners (a product withdrawn from sale).

## Indexes

What to index:
- Named queries come from `pg_stat_statements`: on in every env (dev: `shared_preload_libraries` in compose; stage/prod: the `postgres` module), extension created by `migrate`. Top queries by total time are on the Postgres dashboard ([10](10-alerts.md#dashboards)).
- Each index serves a named query; the PR shows its `EXPLAIN (ANALYZE, BUFFERS)` before and after, on prod-like volume. No index "just in case": each one slows every write.
- Tenant first: RLS puts `tenant_id = …` in every query, so composites lead with `tenant_id`, then equality columns, then the range or sort column: `(tenant_id, status, created_at)`.
- Cast the parameter, never the column, RLS policies included: `tenant_id = current_setting('app.tenant_id')::uuid`. A function on a column needs an expression index on it.
- Every foreign key gets an index led by its columns; Postgres makes none, and a parent delete then scans the child. A catalog test fails on one without.
- Partial for a hot subset: `WHERE deleted_at IS NULL`, a queue's `WHERE status = 'pending'`.
- No index that is a leading prefix of another, unless unique. Uniqueness is a unique index, never an app check.
- Name it `<table>_<columns>_idx`, `_key` if unique.

How to add:
- New table: plain `CREATE INDEX` in the migration that creates it.
- Existing table: `CREATE INDEX CONCURRENTLY`; a plain one blocks writes for the whole build. It can't run in a transaction, so it gets its own file, first line `-- no transaction`, run by the migrator one statement at a time:

```sql
-- no transaction
DROP INDEX CONCURRENTLY IF EXISTS orders_tenant_id_status_created_at_idx;
CREATE INDEX CONCURRENTLY orders_tenant_id_status_created_at_idx ON orders (tenant_id, status, created_at);
```

- A failed concurrent build leaves an INVALID index: hence the `DROP` first, never `IF NOT EXISTS`. `migrate` fails if any index is invalid after its run.
- Unique on an existing table: remove duplicates first, then `CREATE UNIQUE INDEX CONCURRENTLY`.
- Drop: `DROP INDEX CONCURRENTLY`, a release after no query uses it (expand → contract). Unused = `pg_stat_user_indexes.idx_scan = 0` over 30 days of prod stats; never one that backs a constraint.
- Vector (ANN) indexes: on measured need only. They are approximate: ivfflat built on an empty table is random, and a tenant filter after the scan returns fewer rows than asked. Default: exact scan per tenant.
