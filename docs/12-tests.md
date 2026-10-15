# 12 · Tests

| Tier | Command | Runs | Providers | Coverage ≥ 99% of |
|---|---|---|---|---|
| Unit | `scripts/test.sh unit` | CI | none | packages without `integration` or `live` tests |
| Integration, fakes | `scripts/test.sh integration` | CI | fakes · Postgres, MinIO in throwaway containers | packages without `live` tests |
| Integration, real | `scripts/test.sh live` | stage, after deploy | real: sandboxes ([06](06-stage.md)) | packages with `live` tests: real provider clients |
| UI + e2e | `scripts/test.sh e2e` | CI on the built images · stage | fakes in CI, real on stage | — |
| Stress / load | `scripts/load/*` | running stack | fakes | — |

## Rules

- `scripts/test.sh <tier>` is the one entry point, locally and in Jenkins. It starts what the tier needs and writes everything to `reports/<tier>/`: JUnit, coverage, Playwright report, videos.
- A failed test or coverage under 99% fails the build, from the first commit.
- Go runs with `-race`; build tags pick the tier: `integration` needs a service, `live` calls a real provider. Python DAGs: same tiers by `pytest` marker, `--cov`.
- Coverage counts statements over the tier's scope (`-coverpkg`). A package without tests counts as 0%. Left out only code that never runs in prod (`e2e/`, `scripts/`, dev-only `cmd/`), listed in the script. Browser JS: UI tests, not measured.
- Each real provider client is its own package, apart from its interface and `fake` ([01](01-system-design.md)). What a sandbox can't trigger (5xx, timeouts) the package's own `httptest` tests cover, in the same run.
- Integration runs the isolation tests ([01](01-system-design.md#tenant-isolation-mandatory)).
- `TESTS_REQUIRED=1` in CI and stage: a test that would skip for a missing service or credential fails instead.
- Stage runs use stage's test accounts and sandbox credentials, never prod's, and remove what they create. A provider with no sandbox gets read-only or dry-run calls only.

## UI

- Playwright on the running stack, for what HTTP can't show: mouse, keyboard, dialogs. Go e2e covers the rest.
- CI and stage record every test: `PW_VIDEO=on`, 1280×720, plus a trace. Locally only failures.
- Reduced motion: `use: { contextOptions: { reducedMotion: 'reduce' } }`. The walkthrough config sets `'no-preference'`, so its video shows motion ([14](14-ui.md)).
- Walkthrough: one spec walks the main journey slowly (`slowMo`, one worker, own config); stage records it on every deploy.
- Watch: the `.webm` in the build's artifacts, or `npx playwright show-report` on the downloaded report.

## Jenkins

Order in [08](08-release.md#ci-jenkinsfile). Every test stage:

```groovy
stage('Integration') {
  steps { sh 'scripts/test.sh integration' }
  post { always {
    junit 'reports/integration/*-junit.xml'
    recordCoverage id: 'integration', tools: [[parser: 'COBERTURA', pattern: 'reports/integration/*-cobertura.xml']]
    archiveArtifacts artifacts: 'reports/integration/**', allowEmptyArchive: true
  } }
}
```

- UI + e2e stages: the same without `recordCoverage`.
- `options { buildDiscarder(logRotator(artifactDaysToKeepStr: '30')) }`: reports and videos stay 30 days.
