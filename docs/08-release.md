# 08 · Release

## Version

`version.txt` = `MAJOR.MINOR`. CI makes `MAJOR.MINOR.<build>` on `main`, `…-<branch>` elsewhere. Image tag = version, OCI label = git SHA. Git tag on `main`.

## Git

Trunk `main`. Short branches → PR → green CI → merge → delete branch. Commit message says what changed (never `-` or `fix`).

## CI (Jenkinsfile)

1. Triggers, timeout, concurrency lock — in code.
2. Lint: `go vet`, `govulncheck`, `shellcheck`, `hadolint`, stack render with dummy env, duplicate migration numbers, `gitleaks`.
3. Test ([12](12-tests.md)): unit → integration with fakes.
4. SonarQube on `main` ([13](13-code-quality.md)): scan with step 3's coverage; a red gate fails the build.
5. Build once (BuildKit, prod platform) → Trivy (HIGH/CRITICAL with a fix fails) → push → record digests.
6. UI + e2e on those images, with fakes ([12](12-tests.md)).
7. Git tag.
8. Deploy stage (auto) → smoke → integration with real providers → UI + e2e ([12](12-tests.md)).
9. Deploy prod: manual approval, same digests.
10. Messenger notice + Grafana annotation.

CI agent runs on its own VM in the private network (local option: [07](07-prod.md#topology--start-here)); registry login via machine identity.

## Image

- One Dockerfile ([02](02-stack.md)). `golang` builder, `--platform=$BUILDPLATFORM`, cache mounts, `go.mod`/`go.sum` copied first.
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
