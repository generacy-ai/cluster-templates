# Implementation Plan: Add CI to Validate Dockerfiles Build Successfully

**Branch**: `001-summary-add-github-actions` | **Date**: 2026-03-03

## Summary of Approach

Create a single GitHub Actions workflow file (`.github/workflows/ci.yml`) that uses a matrix strategy to validate both `standard` and `microservices` cluster template variants in parallel. Each matrix job will: (1) build the variant's Dockerfile using `docker build`, and (2) validate the variant's `docker-compose.yml` using `docker compose config`. No images are pushed and no containers are started.

This is a minimal, single-file change with no dependencies on external tools or services beyond what GitHub-hosted runners already provide.

## Technical Context

- **Language/Format**: YAML (GitHub Actions workflow syntax)
- **Runtime**: GitHub-hosted `ubuntu-latest` runners (Docker and Docker Compose v2 pre-installed)
- **Dependencies**: None beyond the runner's built-in tooling
- **Files created**: 1 (`/.github/workflows/ci.yml`)
- **Files modified**: 0

## Architecture Overview

```
.github/workflows/ci.yml
  └── Job: validate
        ├── Matrix: [standard, microservices]
        ├── Step 1: Checkout repository
        ├── Step 2: Build Dockerfile (docker build)
        └── Step 3: Validate Docker Compose config (docker compose config)
```

The workflow is intentionally flat — a single job with a 2-element matrix. No reusable workflows, composite actions, or external actions beyond `actions/checkout` are needed.

## Implementation Phases

### Phase 1: Create Workflow File (Single Phase)

**Task**: Create `.github/workflows/ci.yml`

**Workflow triggers**:
- `push` to `main` and `develop` branches
- `pull_request` targeting `main` and `develop` branches
- No path filtering (per clarification Q2 answer)
- No concurrency control (per clarification Q4 answer)

**Job structure**:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  validate:
    name: Validate ${{ matrix.variant }}
    runs-on: ubuntu-latest
    strategy:
      matrix:
        variant: [standard, microservices]
    steps:
      - uses: actions/checkout@v4

      - name: Build Dockerfile
        run: docker build -f ${{ matrix.variant }}/.devcontainer/Dockerfile ${{ matrix.variant }}/.devcontainer/

      - name: Validate Docker Compose config
        env:
          REPO_URL: https://github.com/example/repo
          REPO_BRANCH: main
        run: docker compose -f ${{ matrix.variant }}/.devcontainer/docker-compose.yml config
```

**Key details**:

1. **Matrix strategy**: Uses default `fail-fast: true` (per clarification Q3 answer). Both variants run in parallel but cancel if one fails.

2. **Dockerfile build**: Uses `docker build` with explicit `-f` for the Dockerfile path and the `.devcontainer/` directory as build context. Matches the build commands documented in `CLAUDE.md`. No `--push` flag (FR-010).

3. **Environment variable stubs for compose validation**:
   - `REPO_URL` — no default in compose files, must be stubbed. Set to `https://github.com/example/repo`.
   - `REPO_BRANCH` — has `${REPO_BRANCH:-main}` default but explicitly set for clarity.
   - `HOME` — available by default on GitHub runners (resolves `/home/runner`).
   - `ORCHESTRATOR_PORT`, `WORKER_COUNT` — have `:-default` syntax in compose, no stub needed.
   - The `.env` file referenced via `env_file` has `required: false`, so its absence won't cause errors.

4. **No dummy files**: Per clarification Q6, `docker compose config` validates structure only; the `~/.claude.json` bind mount source doesn't need to exist.

5. **No devcontainer.json validation**: Per clarification Q5, scope is limited to Dockerfiles and Compose files.

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Single workflow file | `.github/workflows/ci.yml` | Simplest approach; one file covers all checks (FR-001) |
| `actions/checkout@v4` | Only external action | Minimal dependency footprint; no Docker-specific actions needed since Docker is pre-installed |
| Matrix over variants | `[standard, microservices]` | Parallel execution, clear per-variant naming in Actions UI (FR-009, US3) |
| Stub env vars on compose step only | `env` block on the step | Keeps stubs scoped to where they're needed; Dockerfile build doesn't need them |
| No `docker buildx` / no BuildKit caching | Plain `docker build` | Spec explicitly excludes caching (out of scope); plain build is simpler and sufficient for validation |

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Base image pull rate-limited | Low | Build fails | `mcr.microsoft.com` images have generous pull limits; GitHub runners have cached popular images |
| External package installs fail (GitHub CLI apt repo, npm packages, Claude install script) | Low | Build fails | These are transient failures; re-running the workflow resolves them. Caching is out of scope but could be added later. |
| `docker compose config` behavior changes across versions | Very Low | Validation may pass/fail unexpectedly | GitHub runner Docker Compose versions are stable within `ubuntu-latest`; pin runner version if needed later |
| Compose env var without default added in future | Medium | `docker compose config` fails with "variable is not set" | Document the stub env vars in the workflow file with a comment; contributors will see the error and know to add stubs |

## Validation

After implementation, verify:

1. **CI passes on current branch**: Push the workflow file and confirm both matrix jobs succeed
2. **Compose validation catches errors**: Locally test by introducing a YAML syntax error in a compose file and running `docker compose config` to confirm it fails
3. **Dockerfile build catches errors**: Locally test by introducing a syntax error in a Dockerfile and running `docker build` to confirm it fails
4. **Matrix naming**: Check the Actions UI shows "Validate standard" and "Validate microservices" as separate entries

## Files to Create

| File | Action | Description |
|------|--------|-------------|
| `.github/workflows/ci.yml` | Create | GitHub Actions workflow for CI validation |

No data models, API contracts, or research artifacts are needed — this is a single-file infrastructure change.
