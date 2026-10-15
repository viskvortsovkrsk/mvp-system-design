# 10 · Alerts

Grafana alerting, provisioned from `deploy/observability/grafana/alerting.yaml`. No UI edits. Evaluate every 1m.

## Rules

| Alert | Fires when | For | Sev |
|---|---|---|---|
| Errors | ERROR lines per service/job, grouped by normalized message, 5m > 0 | 0 | warn |
| 5xx rate | `request completed` with status ≥ 500 per service, 5m > 5% and ≥ 20 requests | 5m | crit |
| Dependency down | any line with `alert=<dep>_unavailable` | 2m | crit |
| Heartbeat missing | no `heartbeat` from a worker/scheduler for 3× its interval | 0 | crit |
| Job stale | last success older than schedule + grace | 0 | crit |
| Job hollow | job "succeeded" but > 10% items failed, or 0 items where some are expected | 0 | warn |
| Replicas short | desired − running > 0 | 5m | crit |
| Crash loop | task starts in 15m > 2 × desired + 2 | 0 | crit |
| Unhealthy | healthcheck replacements in 15m > 0 | 0 | warn |
| Node silent | a known node stops reporting | 5m | crit |
| Disk | `/` or `/var/lib/docker` > 85% (> 95% crit) | 10m | warn |
| Pipeline gap | query error; expected service or node absent from logs; Alloy dropping | 10m | crit |
| Secret in logs | `://user:pass@`, `Bearer `, signed URL query (`Signature=`, `sig=`), `BEGIN … KEY` | 0 | crit |
| Security | `error_kind=security_violation`; auth failures per IP > N / 5m | 0 | warn |
| LLM | model call failures > 5%, or spend per hour > budget | 10m | warn |
| Erasure late | an account erasure or tenant offboarding 5 days from its deadline, not done ([01](01-system-design.md#data-model)) | 0 | crit |
| Backup missing | no new dump in 26h | 0 | crit |
| Cert expiry | < 14 days | 1h | warn |

## Outside the cluster

The cluster can't report its own death:
- External uptime check on public URLs, every 1m; 2 failures → crit.
- Dead man's switch: an always-firing watchdog sent to an external receiver; silence → crit.
- Provider alerts (Terraform module `alerts`): VM down; Postgres down, storage > 85%, connections > 80%; Redis down, memory > 80%. Same channels.

## Routing

- One messenger per project; bot token or webhook + channel ids in the secret manager. Swapping messenger = new contact point, nothing else.
- crit → on-call channel, with resolve. warn → team chat, with resolve.
- `group_by: [alertname, service, job]`, `group_wait: 30s`, `group_interval: 5m`, `repeat_interval: 12h`.
- Alert labels bounded: no ids, IPs, user names. The message links to the Loki query.
- Message ≤ 12 lines and within the messenger's size limit (4 KB where it applies). In provisioning files write `$$` for a literal `$`.

## Business events digest

Not alerts — a feed of what the business did. A 5-minute ticker in `cmd/worker`.

- Reads `event` lines ([04](04-logs.md)) for the window; names from a closed allowlist, everything else ignored.
- Window starts at the last processed timestamp the job stores, never `now-5m`: a failed run loses nothing. Dedupe on `event` + `request_id`.
- Posts to its own channel in the project's messenger. Never the alert channels, never resolve messages.
- Ids and counts only — no names, emails, addresses.
- At most 12 lines per run; the rest as `+N more` with a link to the log query.
- Retries a failed send, and emits a heartbeat with `job=digest` and stores its last success, so `Heartbeat missing` and `Job stale` cover it.
- Stage and dev: own channel, or off.

## Dashboards

Provisioned from `deploy/observability/grafana/dashboards/`. No UI edits. One each:

| Dashboard | Shows |
|---|---|
| Service | rate, errors, duration p50/p95/p99 per route, from `request completed` |
| Jobs | last success, duration, items, failures per `job` |
| LLM | calls, tokens, cost per hour and model, against budget |
| Nodes, Swarm | CPU, memory, disk; replicas desired vs running |
| Postgres | connections, top queries by total time (`pg_stat_statements`, [01](01-system-design.md#indexes)) |
| Business | `event` counts per name |

## No data

- Counts (errors, 5xx): no data = OK.
- Absence (heartbeat, job, node): no data = alert, only while the pipeline is proven alive.
- Query errors: one dedicated alert, not every rule.

## Rules for rules

- Backtest 7 days before enabling; the first deploy is quiet.
- Every alert has an owner and a runbook line in `docs/`.
- Delivery tested end to end. `deploy.sh` fails on an empty bot token or chat id.
- Every incident adds the alert that would have caught it.
