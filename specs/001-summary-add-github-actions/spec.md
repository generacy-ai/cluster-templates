# Feature Specification: Add CI to Validate Dockerfiles Build Successfully

**Branch**: `001-summary-add-github-actions` | **Date**: 2026-03-03 | **Status**: Draft

## Summary

Add a GitHub Actions workflow that validates both cluster template variants (`standard` and `microservices`) build successfully on every push and pull request. The workflow will build both Dockerfiles and validate both Docker Compose configurations, providing fast feedback on template correctness without deploying or running containers.

## User Stories

### US1: CI Validates Dockerfile Builds on Every Change

**As a** template contributor,
**I want** Dockerfiles to be automatically built on every push and PR,
**So that** I know immediately if a change breaks the container image build.

**Acceptance Criteria**:
- [ ] `standard/.devcontainer/Dockerfile` builds without errors in CI
- [ ] `microservices/.devcontainer/Dockerfile` builds without errors in CI
- [ ] Build failures block PR merges when branch protection is enabled
- [ ] Build runs on pushes to `main` and `develop`, and on all PRs

### US2: CI Validates Docker Compose Configuration

**As a** template contributor,
**I want** Docker Compose files to be validated on every push and PR,
**So that** I catch YAML syntax errors or invalid compose schemas before merging.

**Acceptance Criteria**:
- [ ] `standard/.devcontainer/docker-compose.yml` passes `docker compose config` validation
- [ ] `microservices/.devcontainer/docker-compose.yml` passes `docker compose config` validation
- [ ] Missing required env vars are handled gracefully (stub values or env defaults)

### US3: Clear CI Feedback on Failures

**As a** template contributor,
**I want** CI output to clearly indicate which variant and which step failed,
**So that** I can quickly identify and fix the issue.

**Acceptance Criteria**:
- [ ] Each variant runs as a separate matrix entry with a descriptive name
- [ ] Dockerfile build output is visible in the Actions log
- [ ] Compose validation output is visible in the Actions log

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Create `.github/workflows/ci.yml` workflow file | P1 | Single workflow file for all CI checks |
| FR-002 | Trigger on push to `main` and `develop` branches | P1 | These are the primary integration branches |
| FR-003 | Trigger on all pull requests | P1 | Catch issues before merge |
| FR-004 | Build `standard/.devcontainer/Dockerfile` using `docker build` | P1 | Build context: `standard/.devcontainer/` |
| FR-005 | Build `microservices/.devcontainer/Dockerfile` using `docker build` | P1 | Build context: `microservices/.devcontainer/` |
| FR-006 | Validate `standard/.devcontainer/docker-compose.yml` with `docker compose config` | P1 | Must handle env var substitution (see FR-008) |
| FR-007 | Validate `microservices/.devcontainer/docker-compose.yml` with `docker compose config` | P1 | Must handle env var substitution (see FR-008) |
| FR-008 | Provide stub environment variables for compose validation | P1 | Compose files reference `~`, `${REPO_URL}`, `${REPO_BRANCH}`, etc. Set dummy values so `docker compose config` doesn't fail on unset vars |
| FR-009 | Use a matrix strategy to run both variants in parallel | P2 | Matrix over `[standard, microservices]` for clarity and parallelism |
| FR-010 | Use `docker build` without `--push` (build-only, no registry) | P1 | CI only validates buildability; no images are published |
| FR-011 | Do not start or run containers | P1 | Build validation only; no `docker compose up` |

## Technical Design Notes

### Workflow Structure

A single workflow file (`.github/workflows/ci.yml`) with a matrix strategy:

```yaml
strategy:
  matrix:
    variant: [standard, microservices]
```

### Environment Variable Handling

Both `docker-compose.yml` files reference environment variables that won't be set in CI:
- `~` — available by default on GitHub runners
- `${REPO_URL}`, `${REPO_BRANCH}` — have defaults in compose or need stubs
- `${ORCHESTRATOR_PORT}`, `${WORKER_COUNT}` — have defaults via `${VAR:-default}` syntax
- `~/.claude.json` — referenced as a bind mount; needs a dummy file or path for config validation

For `docker compose config`, set minimal stub env vars:
```yaml
env:
  REPO_URL: https://github.com/example/repo
  REPO_BRANCH: main
```

### Runner Requirements

- Use `ubuntu-latest` runner (Docker and Docker Compose v2 are pre-installed)
- No special permissions or secrets required

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | CI passes on current `main`/`develop` | 100% green | GitHub Actions status badge |
| SC-002 | CI runs on every PR | All PRs show CI check | GitHub PR checks tab |
| SC-003 | Build time per variant | Under 10 minutes | GitHub Actions job duration |
| SC-004 | Failure detection accuracy | Catches all Dockerfile syntax/build errors | Manual verification: introduce a deliberate error, confirm CI fails |

## Assumptions

- GitHub-hosted `ubuntu-latest` runners have Docker and Docker Compose v2 pre-installed
- The repository is hosted on GitHub
- No container registry push is needed; CI only validates builds
- The base image `mcr.microsoft.com/devcontainers/typescript-node:22-bookworm` is publicly accessible without authentication
- External package installs (GitHub CLI, Docker CE, npm packages) remain available from CI runners
- Branch protection rules on `main`/`develop` will be configured separately (not part of this feature)

## Out of Scope

- Publishing built images to a container registry (Docker Hub, GHCR, etc.)
- Running containers or executing integration tests inside containers
- Matrix testing with different base images (noted as future consideration in the issue)
- Setting up branch protection rules or required status checks
- Caching Docker layers across CI runs (optimization for later)
- Scheduled/cron-based builds
- Testing entrypoint scripts or runtime behavior
- Notifications (Slack, email) on build failure

---

*Generated by speckit*
