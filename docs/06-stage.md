# 06 · Stage

Purpose: run the exact release — same digests, stack file, migrations, deploy script — before prod.

Env file: `docs/env/stage.md` ([03](03-folders.md#environment-files)).

## Shape

- Same Terraform modules and `deploy/stack.yml` as prod. Own cloud account/project, state, secret store, DB, buckets.
- Small: 1 Swarm node; managed Postgres on the smallest tier, no HA; Redis in Swarm like prod (~25% of prod cost).
- Backups: managed PITR only, 7d. No cold copies.
- Hosts `stage-<svc>.<domain>`, behind SSO at the edge, `X-Robots-Tag: noindex`. `/webhooks/*` skips SSO (the signature is the auth, [01](01-system-design.md#inbound-webhooks)); CI passes with an edge service token.
- Third parties: sandboxes only (payment test terminal, dev store, supplier test accounts).
- Data: synthetic, or a prod copy with every `pii` column ([01](01-system-design.md#data-model)) replaced by fakes. Never raw prod PII.
- Retention per [04](04-logs.md#retention). Alerts → team chat, never the on-call channel.

## Flow

1. CI build on `main` → auto `deploy.sh stage <version>` ([08](08-release.md)).
2. Smoke, integration with real providers, UI + e2e ([12](12-tests.md)); soak ≥ 1 h or one scheduled-job cycle.
3. Promote the same digests to prod.

## Rules

- Stage must run the release candidate. A stage that exists only in Terraform is no stage.
- Can't keep it running → create it per release, destroy after (same modules).
- `TAG` is always a version, never `latest`.
- Blind spots — scale, WAF false positives, failover, CPU credits — go in the release plan.
