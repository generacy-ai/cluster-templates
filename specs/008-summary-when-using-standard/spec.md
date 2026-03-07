# Feature Specification: Eliminate Duplicate Repo Clone in Devcontainer Mode

**Branch**: `008-summary-when-using-standard` | **Date**: 2026-03-07 | **Status**: Draft | **Issue**: [#8](https://github.com/generacy-ai/cluster-templates/issues/8)

## Summary

When using the standard template with VS Code Dev Containers, the project repo gets cloned twice — once by the Dev Containers extension (to `/workspaces/<repo-name>`) and again by the entrypoint scripts (to `/workspaces/project`). This wastes disk space and causes config file conflicts that cascade into worker setup failures.

Additionally, after cloning the primary repo, the entrypoint should pass `--config` to `generacy setup workspace` so it can discover the `.generacy/config.yaml` and clone additional repos listed there.

## Problem

Both `entrypoint-orchestrator.sh` and `entrypoint-worker.sh` unconditionally clone `REPO_URL` to `/workspaces/project`. When opened via VS Code Dev Containers, the extension has already cloned the repo to `/workspaces/<repo-name>`, resulting in:

1. **Two copies of the repo** on disk
2. **Config file conflicts** — `generacy setup workspace` finds multiple `.generacy/config.yaml` files and errors out
3. **Worker setup failures cascade** — the config conflict causes `generacy setup workspace` to fail, feeding into the worker crash loop

## User Stories

### US1: Devcontainer Developer

**As a** developer using VS Code Dev Containers,
**I want** the entrypoint scripts to detect the already-cloned repo and skip redundant cloning,
**So that** I don't get duplicate repos, config conflicts, or worker crash loops.

**Acceptance Criteria**:
- [ ] No duplicate clone when `DEVCONTAINER` or `REMOTE_CONTAINERS` env var is set
- [ ] Existing repo at `/workspaces/<repo-name>` is reused as `WORKSPACE_DIR`
- [ ] `generacy setup workspace` runs successfully without config conflicts

### US2: Docker Compose Developer

**As a** developer using the template via standalone Docker Compose (non-devcontainer),
**I want** the repo to be cloned to `/workspaces/<repo-name>` (derived from URL) instead of hardcoded `/workspaces/project`,
**So that** the workspace path is predictable and consistent with devcontainer mode.

**Acceptance Criteria**:
- [ ] Clone target derived from `REPO_URL` using `basename`
- [ ] `WORKSPACE_DIR` env var can override the derived path
- [ ] Backward-compatible: existing setups continue to work

### US3: Multi-Repo Workspace Setup

**As a** developer with a `.generacy/config.yaml` that lists additional repos,
**I want** the entrypoint to pass `--config` to `generacy setup workspace`,
**So that** additional repos are discovered and cloned automatically.

**Acceptance Criteria**:
- [ ] `--config` flag passed when `.generacy/config.yaml` exists in the workspace
- [ ] Falls back to plain `generacy setup workspace` when no config file exists

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Derive clone path from `REPO_URL` (`basename` without `.git`) | P1 | Replace hardcoded `/workspaces/project` |
| FR-002 | Detect devcontainer mode via `DEVCONTAINER`/`REMOTE_CONTAINERS` env vars | P1 | Skip clone, reuse existing repo |
| FR-003 | Support `WORKSPACE_DIR` env var override | P2 | Takes precedence over derived path |
| FR-004 | Pass `--config` to `generacy setup workspace` when config file exists | P1 | Enables multi-repo discovery |
| FR-005 | Add `WORKSPACE_DIR` to `.env.template` | P2 | Document the override option |
| FR-006 | Pass `WORKSPACE_DIR` through `docker-compose.yml` environment | P2 | Make override available in containers |
| FR-007 | Apply changes to both `standard/` and `microservices/` variants | P1 | Both variants share the same pattern |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | No duplicate repo in devcontainer mode | 0 duplicates | Open in VS Code Dev Containers, verify single repo |
| SC-002 | `generacy setup workspace` succeeds | No config conflict error | Check entrypoint logs |
| SC-003 | Standalone Docker Compose still works | Clone succeeds to derived path | `docker compose up` with `REPO_URL` set |

## Files Affected

- `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` — derive clone path, devcontainer detection, pass --config
- `standard/.devcontainer/scripts/entrypoint-worker.sh` — same changes
- `standard/.devcontainer/.env.template` — add `WORKSPACE_DIR`
- `standard/.devcontainer/docker-compose.yml` — pass `WORKSPACE_DIR` to environment
- `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` — same changes as standard
- `microservices/.devcontainer/scripts/entrypoint-worker.sh` — same changes as standard
- `microservices/.devcontainer/.env.template` — add `WORKSPACE_DIR`
- `microservices/.devcontainer/docker-compose.yml` — pass `WORKSPACE_DIR` to environment

## Assumptions

- The `DEVCONTAINER` or `REMOTE_CONTAINERS` env var is reliably set by VS Code Dev Containers extension
- `REPO_URL` always ends in a parseable repo name (with or without `.git` suffix)
- The entrypoint scripts run as a user with write access to `/workspaces/`

## Out of Scope

- Changing devcontainer.json `workspaceFolder` configuration
- Modifying the Dockerfile itself
- Handling repos cloned to non-`/workspaces/` directories
- Changes to the `generacy` CLI tool itself

## Related

- generacy-ai/tetrad-development#32 (same pattern: clone primary repo first, pass --config to setup workspace)
- #9 (worker crash loop — config conflict from duplicate clone compounds it)
- #7 (template placeholders)

---

*Generated by speckit*
