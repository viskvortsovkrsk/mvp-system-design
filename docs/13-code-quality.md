# 13 · Code quality

SonarQube Community Build checks the integration branch ([08](08-release.md#git)), called `main` below. Agents follow its findings.

## Server

- Own VM next to CI (≥ 4 GB RAM), own Postgres container, pinned image. UI behind the tunnel + SSO, like Grafana ([07](07-prod.md)).
- Community analyzes `main` only, no branches or PRs. Before merge: agents check their files ([Agents](#agents)); people use SonarQube for IDE in connected mode.
- Gate and profiles: built-in "Sonar way": no new issues, new hotspots reviewed, new-code coverage ≥ 80%, duplication ≤ 3%. The 99% coverage gates stay in the test tiers ([12](12-tests.md)).

## Scan

```properties
# sonar-project.properties
sonar.projectKey=<project>
sonar.sources=.
sonar.tests=.
sonar.test.inclusions=**/*_test.go,**/tests/**
sonar.exclusions=**/*_test.go,**/tests/**,src/e2e/**,scripts/**,reports/**
sonar.go.coverage.reportPaths=reports/*/coverage.out
sonar.python.coverage.reportPaths=reports/*/py-cobertura.xml
sonar.qualitygate.wait=true
```

- `sonar.coverage.exclusions`: the real provider clients; their coverage is gated on stage ([12](12-tests.md)).
- Jenkins, after the tests, `main` only: pinned `sonarsource/sonar-scanner-cli`, project token from the secret manager, `-Dsonar.projectVersion=$(cat version.txt)`. A red gate fails the build.
- `projectVersion` is `MAJOR.MINOR`, never the build number: each new version restarts new code, so a failed gate's issues would pass as old code.

## Agents

- SonarQube MCP in `.mcp.json`: pinned `sonarsource/sonarqube-mcp`, `SONARQUBE_READ_ONLY=true`, user token of an `agent` user with Browse only.
- A change is done when every changed file Sonar can analyze passes `analyze_code_snippet` with no findings, and `main`'s gate is green.
- Fix the finding in the code. Never silence it: no `NOSONAR`, won't fix, false positive, or rule, profile or gate change. Those, and a finding that contradicts these docs, are the user's call; the reason goes next to it.
- A red gate on `main` is fixed before new work.
- Scope: what the change adds or edits. Older findings stay (touch only what's asked).
