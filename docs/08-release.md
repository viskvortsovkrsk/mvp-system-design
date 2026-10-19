# 08 · Release

## Version

`version.txt` = `MAJOR.MINOR`. CI makes `MAJOR.MINOR.<build>` on the integration branch ([Git](#git)), `…-<branch>` elsewhere. Image tag = version, OCI label = git SHA. Git tag on `main`.

## Git

Git is mandatory from the first line of code. Host: GitHub (default) or Bitbucket ([02](02-stack.md)).

| Phase | Flow | Integration branch |
|---|---|---|
| Start, until stage and prod run | `<branch>` → PR → `main` | `main` |
| Stage and prod running | `<branch>` → PR → `develop` → release PR → `main` | `develop` |

- `main` is locked from day 1, `develop` from when it exists: no direct commits by anyone, owner included; changes only by PR with green CI; no force-push, no deletion. A ruleset on the host, no bypass.
- CI builds, scans and deploys stage from the integration branch ([CI](#ci-jenkinsfile)).
- Release PR `develop` → `main`: on merge, `main` is tagged and prod gets the digests stage tested for that `develop` commit. Never rebuilt.
- Hotfix: branch from `main` → PR → `main` (built, stage, prod) → merge `main` back into `develop`.
- Short branches, deleted after merge. Commit message says what changed (never `-` or `fix`).

- Author ≠ approver: a PR is approved by a person who did not write it; an agent's PR by a person. Enforced by `main` protection ([15](15-security.md#people-and-accounts)), never waived by admins.
- One person on the project: deviation in `docs/00-mvp-system-design.md` ([agent rules](../agent-rules.md#1-follow-mvp-system-design)) with the compensating control (the owner reviews each release's diff after deploy, noted in `docs/releases/<ver>.md`). Before a SOC 2 window, a second approver.

## CI (Jenkinsfile)

1. Triggers, timeout, concurrency lock — in code.
2. Lint: `go vet`, `govulncheck`, `shellcheck`, `hadolint`, stack render with dummy env, duplicate migration numbers, `gitleaks`.
3. Test ([12](12-tests.md)): unit → integration with fakes.
4. SonarQube on the integration branch ([13](13-code-quality.md)): scan with step 3's coverage; a red gate fails the build.
5. Build once (BuildKit, prod platform) → Trivy (HIGH/CRITICAL with a fix fails) → push → record digests.
6. UI + e2e on those images, with fakes ([12](12-tests.md)).
7. Git tag.
8. Deploy stage (auto) → smoke → integration with real providers → UI + e2e ([12](12-tests.md)).
9. Deploy prod: manual approval (`input`, `submitter` = approvers group, `submitterParameter`; fails when the approver wrote a commit in the release), same digests. The approver is kept in the build record ([12](12-tests.md#jenkins)).
10. Messenger notice + Grafana annotation.

CI agent runs on its own VM in the private network (local option: [07](07-prod.md#topology--start-here)); registry login via machine identity.

## Image

- One Dockerfile ([02](02-stack.md)). `golang` builder, `--platform=$BUILDPLATFORM`, cache mounts, build context = repo root, `src/go.mod`/`src/go.sum` copied first.
- `CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=<ver>"` for every `cmd/*` → `/app/<bin>`. The stack picks one per service via `command`.
- Runtime image per [02](02-stack.md). Exec-form entrypoint. Healthcheck set per service in the stack ([07](07-prod.md)).
- `.dockerignore`: `.git`, `.env*`, secrets, tests, local binaries. No secrets in build args or layers.

## `deploy.sh <env> <version>`

1. Preflight: required vars non-empty (`${X:?}`), images exist, secrets exist, schema not dirty.
2. Sync secrets; hash configs.
3. Migration locks or rewrites tables → take an on-demand DB backup first.
4. Migrate: one-shot job, role per [01](01-system-design.md#postgres-roles), straight to Postgres (not the pooler), timeout; a failed job is kept for inspection.
5. `docker stack deploy --with-registry-auth --prune -c deploy/stack.yml <project>`.
6. Wait until every service runs the target image with all tasks healthy; otherwise fail.
7. Smoke: `/readyz` per service + one business check.

## Rollback

- Failed update → Swarm rolls back by itself.
- Bad release → `deploy.sh prod <previous>`.
- The DB never rolls back: migrations are additive; destructive ones ship a release later, once no code uses the old shape.
- Risky features ship behind a flag: env var `FEATURE_<NAME>=on`, default off, listed in `.env.example`, set in `deploy/<env>.env`. Flipping it = a deploy. Removed once on everywhere. Scheduled jobs start paused on first deploy.

## Pins

- Monthly, a recurring task in the tracker ([11](11-tasks.md)): bump Go, Go modules (`go get -u ./... && go mod tidy`), Python deps, every `tag@digest` (Dockerfile, compose, stack, observability). One PR, normal CI.
- Weekly Jenkins run on `main`: `govulncheck` + Trivy on the deployed digests, so a new CVE in unchanged code shows up. Red → fixed before new work.

## Paper trail

- `docs/releases/<ver>.md`: changes, migrations (additive? locking?), steps, rollback, verification result.
- `docs/incidents/YYYY-MM-DD-slug.md`: timeline, impact, how detected, root cause, fixes, the alert that would have caught it.
