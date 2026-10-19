# 16 · Rate limits

## Scope

- Every action a user can take other than reading has limits: each unsafe-method route, each job a user starts, each email, upload or LLM call a user causes.
- Reads: per IP at the edge only.
- Unauthenticated writes (login, signup, forms): per IP at the edge (WAF rate rules), plus the app limits once a user is known.
- Exempt, each listed with its reason: signed webhooks ([01](01-system-design.md#inbound-webhooks)), `/internal/*`, logout.

## Limits

Per action, two scopes:

| Scope | Counts | Required |
|---|---|---|
| `user` | one user's calls | every action |
| `global` | all users' calls together | LLM actions; others when one action can exhaust a shared resource |

Per scope, windows:

| Window | Field | Required |
|---|---|---|
| second or minute, fixed | `per_second` or `per_minute`, one of them | yes |
| day, UTC | `per_day` | yes |
| month, UTC calendar | `per_month` | when a monthly cost or quota exists |

Each scope has `mode`:
- `enforce`: over a limit → rejected.
- `alert`: never rejects; same counters and events. For tuning a new limit, ≤ 14 days, then set from observed p99 × 3 and switch to `enforce`.

## LLM

- Every action that calls a model has `user` and `global` scopes, both `enforce` in stage and prod. Startup fails otherwise.
- The LLM client takes the action name and refuses an action without them. Limits count calls; the cost ceiling ([01](01-system-design.md#rules)) counts money. Both apply.

## Config

`deploy/ratelimits.json`, one file, a Swarm config with a hashed name ([07](07-prod.md#swarm-service)); dev compose mounts the same file. Changing a limit or mode = a deploy.

```json
{
  "comment_create": {
    "user":   {"mode": "enforce", "per_minute": 10, "per_day": 200}
  },
  "summary_generate": {
    "user":   {"mode": "enforce", "per_minute": 3,   "per_day": 50,    "per_month": 600},
    "global": {"mode": "enforce", "per_minute": 300, "per_day": 20000, "per_month": 300000}
  }
}
```

- Action names = the log `action` enum ([04](04-logs.md)).
- Startup fails on an action in code without an entry, an entry with no action, a missing required window, or an LLM action breaking the rule above.
- Coverage test, like isolation ([01](01-system-design.md#tenant-isolation-mandatory)): every unsafe route in `main.go` and every user-started job maps to an action or `exempt: <why>`; an unlisted one fails the build.

## Counters

- In Redis ([07](07-prod.md#redis)), client `go-redis`, package `internal/ratelimit`; every service uses it directly. Shared across replicas by design. In-memory counters are never limits.
- Key per window: `rl:<action>:<subject>:<period>:<period_start>`, `subject` = `u:<user_id>` or `global`. TTL = window length + 1 hour (month: to its end + 1 day). No cleanup job.
- One script per call checks every window, then increments all of them: a rejected call counts nowhere. `ARGV` = limit per key (`0` for `alert`), then TTL per key.

```lua
for i, k in ipairs(KEYS) do
  local lim = tonumber(ARGV[i])
  if lim > 0 and tonumber(redis.call('GET', k) or '0') >= lim then return {-i} end
end
local out = {}
for i, k in ipairs(KEYS) do
  out[i] = redis.call('INCR', k)
  redis.call('EXPIRE', k, ARGV[#KEYS + i], 'NX')
end
return out
```

- Loaded once (`redis.NewScript`: `EVALSHA`, falls back to `EVAL`). `{-i}` names the full window, for `Retry-After`.
- Redis down or slower than 50 ms:
  - LLM actions and actions with a `global` scope fail closed: `503`, `Retry-After: 30`.
  - Others fail open.
  - Both: WARN, and the `redis_unavailable` probe pages ([04](04-logs.md#every-service-emits), [10](10-alerts.md#rules)).
- Redis lost → counters restart from zero. Accepted: the LLM money ceiling in Postgres ([01](01-system-design.md#rules)) still holds.

## Rejected

- `429` with `Retry-After` = seconds to the end of the full window.
- The page or JSON says which cap (minute, day, month) and when it resets, in the user's language.
- No side effect. The `request completed` line has status 429.

## Events

Business events ([04](04-logs.md), digest per [10](10-alerts.md#business-events-digest)), each with `action`, `scope`, `period`, `limit`, `mode`, and `user_id`/`tenant_id` for `user`:

| `event` | When |
|---|---|
| `rate_limit_warning` | the script returns `ceil(0.75 × limit)`: once per window |
| `rate_limit_hit` | the script returns `limit`: once per window, both modes |

- `global` hits also alert ([10](10-alerts.md#rules)): everyone is blocked.
- Dashboard: usage against limit per action and scope, 429s, warnings and hits ([10](10-alerts.md#dashboards)).

## Tests

- Per action: limit + 1 calls in `enforce` → the last gets 429, no side effect, counters unchanged; in `alert` → all pass.
- Redis stopped: LLM and `global` actions get 503, others pass.
- Warning and hit events emitted exactly once per window.
- Two replicas share one counter: the stack test splits calls between them.
- Startup fails for each broken config case above.
