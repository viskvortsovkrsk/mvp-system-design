# 04 · Logs

## Format

```json
{"time":"2026-09-19T10:15:02.123456Z","level":"ERROR","message":"request completed","service":"api","version":"1.0.73","environment":"prod","instance":"api.2","request_id":"0199a3c2-…","source":"web","action":"game_start","tenant_id":"t_41","user_id":"u_9","method":"POST","route":"/games/{id}","status":502,"duration_ms":1830,"error":"dial tcp: i/o timeout","error_kind":"timeout"}
{"time":"2026-09-19T10:15:03.004118Z","level":"INFO","message":"model call","service":"api","version":"1.0.73","environment":"prod","instance":"api.2","request_id":"0199a3c3-…","source":"web","action":"game_turn","tenant_id":"t_41","user_id":"u_9","model":"claude-haiku-4-5","tokens_in":1320,"tokens_out":210,"cost_micros":2200,"latency_ms":1400}
{"time":"2026-09-19T10:16:00.000211Z","level":"INFO","message":"heartbeat","service":"worker","version":"1.0.73","environment":"prod","instance":"worker.1"}
```

- JSON Lines: one flat object per line, UTF-8, stdout. No pretty-print, no multi-line (a stack is one escaped string). Same format in every env; read it locally with `jq`.
- Key order: `time`, `level`, `message`, base fields, the rest.
- Keys: snake_case, one meaning across all services, added to the table below before first use.
- `message`: constant, lowercase, no variables, no trailing dot. `"request completed"`, never `"user 9 started game 7"`.
- Numbers are JSON numbers; the unit goes in the key (`_ms`, `_bytes`, `_micros`). Ids are strings.
- Inside a request or job, context fields are always present, `null` while unknown. Anything else is omitted when empty.
- Limits: `error` ≤ 512 chars, any string ≤ 1 KB, line ≤ 16 KB. Truncate, never split.
- Every line is JSON with a real level: no `fmt.Print*`, no `log.Print*`.
- Python: same keys through a JSON formatter. Third-party output (Airflow, Caddy) is mapped to `time` / `level` / `message` in Alloy; plain text gets `level=UNKNOWN`.

Go setup, once in `main`:

```go
h := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: level, // from LOG_LEVEL
	ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
		switch {
		case len(groups) > 0:
		case a.Key == slog.TimeKey:
			return slog.String("time", a.Value.Time().UTC().Format(time.RFC3339Nano))
		case a.Key == slog.MessageKey:
			a.Key = "message"
		}
		return a
	}})
slog.SetDefault(slog.New(h).With("service", service, "version", version, "environment", env, "instance", instance))
```

## Fields

| Field | When | Example |
|---|---|---|
| `time` | always, UTC, RFC3339Nano | 2026-09-19T10:15:02.123456Z |
| `level` | always | DEBUG · INFO · WARN · ERROR |
| `message` | always, constant | request completed |
| `service` `version` `environment` `instance` | always | api · 1.0.73 · prod · api.2 |
| `request_id` | request or job | UUIDv7 |
| `source` `action` | HTTP | web · game_start (closed enum) |
| `tenant_id` `user_id` | request; null before auth | opaque ids |
| `client_ip` | edge requests; from the trusted proxy header | 203.0.113.7 |
| `method` `route` `status` `duration_ms` | request completed | POST · /games/{id} · 502 · 1830 |
| `error` `error_kind` | WARN/ERROR; `error` redacted, ≤512 chars | … · timeout |
| `stack` | panics only | |
| `event` | business events; closed allowlist, digested every 5 min ([10](10-alerts.md#business-events-digest)) | payment_succeeded |
| `job` `run_id` `attempt` | batch jobs | orders_sync · … · 2 |
| `dep` `dep_status` `attempts` | outbound calls | shopify · 429 · 3 |
| `model` `tokens_in` `tokens_out` `cost_micros` `latency_ms` | LLM calls | |
| `alert` | lines that must page ([10](10-alerts.md)) | datastore_unavailable |

`error_kind`: timeout · unavailable · dependency · db · validation · auth · security_violation · client_error · panic · config.

## Every service emits

- `started`: version and config hash, no secrets.
- `request completed`: one per request, from middleware.
- `heartbeat`: every long-running worker/scheduler, every 1–5 min.
- `model call`: every LLM call.
- `<dep>_unavailable` with `alert=`: dependency probe, every minute, while failing.

## Levels

| Level | When |
|---|---|
| DEBUG | internals, health probes |
| INFO | request < 500, start/stop, job done, heartbeat, LLM call, business event |
| WARN | served but degraded: retry succeeded, fallback, slow, upstream 4xx caused by the customer, 499 client gone, dropped record, security violation |
| ERROR | our failure: 5xx, panic, dependency down, retries exhausted, job failed — always with `error_kind`, cause and `request_id` |

Never sample WARN, ERROR or request lines.

## Never log

Secrets, tokens, cookies, DSNs, signed URLs (strip the query), request/response bodies, prompts and user text, names, emails, phones, addresses. Ids only.

## Correlation

- `request_id` is made by the first service; accepted from outside only from authenticated internal callers; forwarded as `X-Request-ID` on every outbound call.
- Handlers log through the request logger from `context`, never the global `slog`.

## Pipeline

app stdout → Docker json-file (max-size 50m × 3) → Alloy on every node (containers, host journal incl. dockerd, job log files) → Loki on object storage → Grafana + Grafana MCP.
One-shot jobs (migrate) must land in Loki too.

## Labels

- Indexed: `environment` `service` `node` `instance` `level` (+ `job`). ≤ 10.
- `instance` = `<service>.<slot>` (`api.2`); the slot comes from `TASK_SLOT={{.Task.Slot}}` in the stack's `environment`. Never the container id (changes every deploy).
- Ids, route, status, user, IP, image = JSON fields or structured metadata. Never labels.
- Alloy normalizes level: WARNING → WARN; plain-text lines → regex, else UNKNOWN.

## Retention

| Data | Keep |
|---|---|
| ops logs, metrics | prod 30d · stage/dev 7d |
| security audit | ≥ 1y, append-only, own table |
| access and change trail: cloud audit log, console sign-ins, VPN and SSH sessions, CI builds and deploys | ≥ 400d (a 12-month audit window + lag), outside the cluster |
| domain journals (LLM interactions, game logs) | own store, TTL ≤ 180d, never copied into ops logs |
| alert chat | auto-delete ≤ 30d |
