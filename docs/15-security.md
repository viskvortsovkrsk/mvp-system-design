# 15 · Security

Rules not covered elsewhere. Already decided, kept where they are:

| Topic | Where |
|---|---|
| Edge, admin access, firewall | [01](01-system-design.md) diagram · [07](07-prod.md#topology--start-here) |
| Cookie, revocation, CSRF, headers, CSP, body caps | [01](01-system-design.md#web-security) |
| Rate limits | [16](16-rate-limits.md) |
| Webhooks | [01](01-system-design.md#inbound-webhooks) |
| DB roles, tenant isolation, PII, erasure | [01](01-system-design.md#postgres-roles) · [isolation](01-system-design.md#tenant-isolation-mandatory) · [data model](01-system-design.md#data-model) |
| Secrets: tree, agents, store, rotation | [03](03-folders.md#rules) · [07](07-prod.md#secrets) |
| What never goes in logs | [04](04-logs.md) |
| Stage data, SSO | [06](06-stage.md) |
| Scans, image, pins | [08](08-release.md#ci-jenkinsfile) · [pins](08-release.md#pins) |
| Security alerts | [10](10-alerts.md#rules) |

## Threat model

- Each project keeps `docs/NN-threats.md`: one table, updated in the PR that adds an entry point or a data class.

| Asset | Who wants it | Entry point | Control | Test |
|---|---|---|---|---|
| tenant data | other tenant | api routes | RLS + isolation tests | coverage test |

## Authorization

- Deny by default. Every route declares what it needs: `public`, `user`, `role:<name>`, `internal`, `webhook`. A route without one fails at startup.
- Checked in the handler's wrapper from the session's role, read from the `sessions` row's user, never from input.
- Coverage test, like isolation ([01](01-system-design.md#tenant-isolation-mandatory)): every route in `main.go` has its requirement and a test that a caller one level below gets 403 (404 where existence is secret), with no side effect.
- Denied → WARN, `error_kind=security_violation`.
- Admin UI and admin routes: own binary or `/admin/*`, `role:admin`, MFA required (IdP `amr` claim, checked per request), every write audited.

## Sign-in

- OIDC authorization code + PKCE; `state` and `nonce` checked; redirect URIs registered exactly, no wildcards.
- Post-login return path: relative only (`/` first, not `//`, no `\`), else `/`. Same for any `?next=`: no open redirects.
- New `sid` on every sign-in and role change.
- User identity = IdP subject. Accounts are linked by email only when the IdP marks it verified.
- Same answer and timing for "no such account" and "wrong code" where the flow is ours.

## Audit log

- `audit_events` (owner: api): `actor_id`, `actor_role`, `action`, `target_type`, `target_id`, `tenant_id`, `request_id`, `created_at`. Ids only, no PII.
- Written in the same transaction as the action: admin and support actions, role changes, data exports, erasure requests, secret or key changes made in the app.
- `REVOKE UPDATE, DELETE` from `app`. Retention: [04](04-logs.md#retention).
- Support reads through `readonly` over VPN ([01](01-system-design.md#postgres-roles)). Acting as a user: reason required, 1 hour max, audited, shown to the user in their account.

## Untrusted input

Input = request, file, webhook payload, provider response, model output.
- HTML only through `html/template`. Never `template.HTML`, `template.JS`, `template.URL` on data that can hold input.
- SQL only with parameters. Identifiers (sort column, direction) from a fixed map.
- File paths: `os.Root`, never `filepath.Join` with input. Archives: each entry checked with `filepath.IsLocal`, total size and count capped.
- Decompressed size capped, not just the compressed body.
- No `os/exec` with input. No YAML or XML from users; JSON only.
- Redirects: to own paths or a fixed allowlist.

## Uploads

- Cap per route; stream to the bucket ([07](07-prod.md#buckets--one-per-task)).
- Type from the content (`http.DetectContentType`) against an allowlist, never from the name or `Content-Type`.
- Object key = `uuidv7()`. The user's file name is a `pii` column, never a path.
- Images re-encoded server-side: strips EXIF (GPS is PII) and polyglots.
- Served by signed URL with `Content-Disposition: attachment`, except allowlisted image types. SVG and HTML never inline.

## Outbound requests

- Provider URLs are config, never input.
- Fetching a URL the user gave: `https` only; a `net.Dialer.Control` rejects loopback, private, link-local (cloud metadata) and unspecified addresses after DNS; each redirect re-checked, max 3; timeout and size cap.
- Test: a URL resolving to `127.0.0.1` and one to `169.254.169.254` are refused.

## Tokens and keys

- Random from `crypto/rand`, 32 bytes. Compare with `subtle.ConstantTimeCompare`. No own crypto.
- API tokens we issue: prefix (`<project>_`), stored as SHA-256 hash in a secrets table ([01](01-system-design.md#postgres-roles)), shown once, scoped, expiring, `last_used_at`.
- Provider tokens we must keep (OAuth refresh): AES-GCM with a key from `*_FILE`, key id stored with the row.
- Cookie signing key: `kid` in the cookie; rotation = add new key → sign with it → drop old after 15 min.
- At rest: managed DB, buckets, volumes and backups encrypted with provider keys. Laptops: full-disk encryption, screen lock.

## LLM

- Model output is untrusted input (above): escaped, validated against a schema, never run, never a SQL fragment, path or URL without the same checks.
- A prompt holds only the caller's tenant data. No secrets in prompts.
- Tools the model calls run with the caller's rights; writes need the user's confirmation.
- The system prompt is not a boundary: assume users read and override it.

## People and accounts

- Every console (cloud, edge/DNS, registry, git host, IdP, payments, email, messenger, tracker): personal account, SSO or 2FA (hardware key or TOTP). No shared logins.
- Root/owner accounts: hardware key, unused day to day, recovery codes offline.
- Least privilege per person; prod write access for whoever deploys, nobody else.
- Git host: `main` and `develop` locked ([08](08-release.md#git)), secret scanning on.
- Offboarding, same day: remove from IdP, VPN, consoles, git host; rotate every secret they could read ([07](07-prod.md#secrets)).
- Agents: read-only everywhere ([02](02-stack.md) AI ops, [03](03-folders.md#rules)); no prod write credentials.

## Supply chain

- `go.sum` committed; builds `-mod=readonly`; `GOSUMDB` on.
- New dependency: the PR says why, that it is maintained, and its license. Prefer stdlib.
- npm: lockfile, `npm ci --ignore-scripts`.
- No `curl | sh` in Dockerfile, CI or scripts. Downloads pinned by checksum.
- Jenkins and its plugins bumped with the monthly pins ([08](08-release.md#pins)).

## Vendors

- A vendor that receives customer data or prod access has a current SOC 2 Type II report. None → it gets neither, or the project records a deviation.
- Project keeps `docs/NN-vendors.md`: vendor, what it gets, report period, next review. Reports downloaded and reviewed yearly (a tracker task, [11](11-tasks.md)). The privacy notice lists the same vendors ([01](01-system-design.md#data-model)).
- Self-hosted tools (Jenkins, SonarQube, Grafana stack, Airflow) are our controls, not vendors.

Status checked 2026-10; re-check before relying on it. Clouds: [09](09-cloud.md#buy-list).

| Vendor ([02](02-stack.md)) | Gets | SOC 2 Type II |
|---|---|---|
| Cloudflare: DNS, WAF, TLS, Tunnel, Access | all traffic | yes, in the dashboard |
| Auth0 (default IdP) | identities | yes, Support Center |
| Resend | emails, recipients | yes, in the dashboard |
| Anthropic: LLM, Claude Design | prompts, design files | yes, trust portal |
| GitHub (default git host) | code | yes |
| Bitbucket (git host option) | code | yes, Atlassian trust page |
| ngrok (dev tunnel) | dev traffic only | yes, trust portal |
| Jira (default tracker, [11](11-tasks.md)) | tasks | yes, Atlassian trust page |
| Linear (tracker option) | tasks | yes, on request |
| Todoist (tracker option) | tasks, no customer data | **no**: Type I only (Type II claimed, not verified); not for a SOC 2 project |
| Slack (default alert messenger, [10](10-alerts.md#routing)) | alert text | yes, Salesforce compliance portal |
| Telegram (alert messenger option) | alert text, no customer data ([04](04-logs.md#never-log)) | **no**: allowed only because it gets no customer data; not for a SOC 2 project |

## Launch

Before the first prod user, then yearly:
- Review the code and config against this doc and [01](01-system-design.md#web-security); findings → tasks with label `security` ([11](11-tasks.md)).
- Smoke ([08](08-release.md#deploysh-env-version)) checks the security headers on every public host.
- Weekly Jenkins run: pinned ZAP baseline scan against stage; new HIGH → priority 1.
- `/.well-known/security.txt` (RFC 9116) from Caddy: `Contact`, `Expires` ≤ 1 year (renewed with the pins), `Policy`. Public repos also get `SECURITY.md`.
- External pentest when a customer contract asks or before handling payments outside a merchant of record.

## Incident

Runbook in the project's `docs/`, rehearsed once before launch:
1. Contain: block at the edge; revoke sessions (delete `sessions` rows → out within 15 min; rotate the cookie key → out now).
2. Rotate every secret that may have leaked ([07](07-prod.md#secrets)).
3. Preserve logs and DB state before cleanup.
4. Scope: which `pii` columns ([01](01-system-design.md#data-model)) and tenants were reachable.
5. Personal data breach: hand the facts from step 4 to the owner. Never notify the authority, users or tenants yourself; the owner decides and sends. Their clock: authority within 72 hours (GDPR Art. 33), users without undue delay if high risk (Art. 34), tenants per contract.
6. Write `docs/incidents/` ([08](08-release.md#paper-trail)) with the test and alert that would have caught it.
