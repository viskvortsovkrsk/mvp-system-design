# 05 · Dev

```sh
cp .env.example .env
docker compose up -d --build --wait     # whole system on localhost
scripts/reset-db.sh                      # drop → migrate → seed
```

Env file: `docs/env/dev.md` ([03](03-folders.md#environment-files)).

## compose.yaml

- Top-level `name: <project>`; no `container_name` (parallel worktrees).
- Same image, binaries, Caddy routes and security headers as prod.
- Postgres = prod major version. `migrate` (one-shot) → `db-roles` (sets `app` and `readonly` passwords) → apps connect as `app`.
- MinIO (S3 API) with the same buckets as prod, created by an init job. Redis: the prod service and files ([07](07-prod.md#redis)).
- Loki, Alloy, Prometheus, Grafana mounted from `deploy/observability/` — same files as prod.
- Host ports: `127.0.0.1` only, unique per project, overridable in `.env`. Never default 5432/8080/3000.
- Images pinned ([02](02-stack.md)).
- Profiles: `tools` (seed, publish), `test` (stub IdP, mocks), `debug`.

## External services

- Default = `fake` or local mock (payments, IdP, suppliers). Sandbox keys opt-in.
- Dev login (`?as=<name>`), fake payments: dev only, fatal in prod ([01](01-system-design.md)).
- Dev credentials have no prod scope: separate IdP app/tenant, separate store/sandbox.
- Inbound webhooks / OAuth callbacks: `cloudflared` or `ngrok` tunnel, one hostname per developer.

## Data

Seeds are repo fixtures, idempotent. Never prod dumps.

## Inner loop

- Service being edited: `go run ./cmd/<bin>` against compose deps; the rest stays in containers.
- DAGs: bind-mounted, live reload.

## Tests

Tiers, commands, coverage: [12](12-tests.md).
