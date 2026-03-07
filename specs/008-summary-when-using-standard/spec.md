# Feature Specification: Eliminate duplicate repo clone in devcontainer mode

**Branch**: `008-summary-when-using-standard` | **Date**: 2026-03-07 | **Status**: Draft | **Issue**: #8

## Summary

When using the standard template with VS Code Dev Containers, the project repo gets cloned twice — once by the Dev Containers extension (to `/workspaces/<repo-name>`) and again by the entrypoint scripts (to `/workspaces/project`). This wastes disk space and causes config file conflicts.

Additionally, after cloning the primary repo, the entrypoint should pass `--config` to `generacy setup workspace` so it can discover the `.generacy/config.yaml` and clone additional repos listed there.

## Problem

Both `entrypoint-orchestrator.sh` and `entrypoint-worker.sh` unconditionally clone `REPO_URL` to `/workspaces/project`:

```bash
if [ -n "${REPO_URL:-}" ] && [ ! -d "/workspaces/project/.git" ]; then
    git clone --branch "${REPO_BRANCH:-main}" "${REPO_URL}" /workspaces/project
```

When opened via VS Code Dev Containers, the extension has already cloned the repo to `/workspaces/<repo-name>`. This results in:

1. **Two copies of the repo** — wasted disk space
2. **Config file conflicts** — `generacy setup workspace` finds multiple `.generacy/config.yaml` files and errors out
3. **Worker setup failures cascade** — The config conflict causes `generacy setup workspace` to fail, feeding into the worker crash loop

## Proposed Solution

### 1. Derive repo name from REPO_URL and clone to `/workspaces/<repo-name>`

Replace hardcoded `/workspaces/project` with a path derived from the repo URL:

```bash
REPO_NAME=$(basename "${REPO_URL%.git}")
WORKSPACE_DIR="/workspaces/${REPO_NAME}"

if [ -n "${REPO_URL:-}" ] && [ ! -d "${WORKSPACE_DIR}/.git" ]; then
    git clone --branch "${REPO_BRANCH:-main}" "${REPO_URL}" "${WORKSPACE_DIR}"
fi
```

### 2. Detect devcontainer mode and skip clone

When running inside a devcontainer, the repo is already available. Detect this and skip:

```bash
if [ -n "${DEVCONTAINER:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ]; then
    EXISTING_REPO=$(find /workspaces -maxdepth 2 -name ".git" -type d 2>/dev/null | head -1)
    if [ -n "$EXISTING_REPO" ]; then
        WORKSPACE_DIR="$(dirname "$EXISTING_REPO")"
        log "Devcontainer mode: using existing repo at $WORKSPACE_DIR"
    fi
fi
```

### 3. Pass `--config` to `generacy setup workspace`

After cloning/detecting the primary repo, pass the config path explicitly:

```bash
CONFIG_PATH="${WORKSPACE_DIR}/.generacy/config.yaml"
if [ -f "$CONFIG_PATH" ]; then
    generacy setup workspace --config "$CONFIG_PATH"
else
    generacy setup workspace
fi
```

### 4. Add WORKSPACE_DIR to .env.template

```env
# Workspace directory override (default: derived from REPO_URL)
# WORKSPACE_DIR=/workspaces/my-project
```

## User Stories

### US1: Developer using VS Code Dev Containers

**As a** developer using VS Code Dev Containers,
**I want** the entrypoint to detect that my repo is already cloned,
**So that** I don't get duplicate repos and config file conflicts.

**Acceptance Criteria**:
- [ ] No duplicate clone occurs when opened via VS Code Dev Containers
- [ ] Entrypoint detects existing repo via `DEVCONTAINER` or `REMOTE_CONTAINERS` env vars
- [ ] `generacy setup workspace` runs without config conflicts

### US2: Developer using standalone Docker Compose

**As a** developer using standalone Docker Compose (not devcontainers),
**I want** the repo cloned to `/workspaces/<repo-name>` instead of `/workspaces/project`,
**So that** the path matches what devcontainer mode uses and is more descriptive.

**Acceptance Criteria**:
- [ ] Clone path derived from `REPO_URL` basename
- [ ] Optional `WORKSPACE_DIR` env var overrides the derived path
- [ ] Backwards compatible — existing setups continue to work

### US3: Multi-repo workspace setup

**As a** developer with a `.generacy/config.yaml` listing additional repos,
**I want** the entrypoint to pass `--config` to `generacy setup workspace`,
**So that** additional repos are discovered and cloned automatically.

**Acceptance Criteria**:
- [ ] `--config` flag passed when `.generacy/config.yaml` exists in the workspace
- [ ] Falls back to no `--config` if the file doesn't exist

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Derive clone path from `REPO_URL` basename instead of hardcoding `/workspaces/project` | P1 | Both entrypoint scripts |
| FR-002 | Detect devcontainer mode and skip clone when repo already exists | P1 | Check `DEVCONTAINER` / `REMOTE_CONTAINERS` env vars |
| FR-003 | Pass `--config` to `generacy setup workspace` when config.yaml exists | P1 | Same pattern as tetrad-development#32 |
| FR-004 | Support `WORKSPACE_DIR` env var override | P2 | Added to `.env.template` |
| FR-005 | Pass `WORKSPACE_DIR` through docker-compose.yml environment | P2 | |

## Files Affected

- `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` — derive clone path, add devcontainer detection, pass --config
- `standard/.devcontainer/scripts/entrypoint-worker.sh` — same changes
- `standard/.devcontainer/.env.template` — add `WORKSPACE_DIR`
- `standard/.devcontainer/docker-compose.yml` — pass `WORKSPACE_DIR` to environment
- `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` — same changes (if applicable)
- `microservices/.devcontainer/scripts/entrypoint-worker.sh` — same changes (if applicable)

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | No duplicate repo clone in devcontainer mode | Zero duplicates | Open repo in VS Code Dev Container, verify single clone |
| SC-002 | No config file conflicts | Zero errors | `generacy setup workspace` completes without "Multiple config" error |
| SC-003 | Standalone Docker Compose still works | Clone succeeds | Run `docker compose up` with `REPO_URL` set, verify clone to correct path |

## Assumptions

- Dev Containers extension sets `DEVCONTAINER` or `REMOTE_CONTAINERS` environment variable
- `REPO_URL` always ends with `.git` or the basename is still meaningful without it
- The `generacy` CLI supports `--config` flag on `setup workspace` command

## Out of Scope

- Changes to the `generacy` CLI itself
- Modifying how VS Code Dev Containers extension clones repos
- Handling multiple primary repos (only one `REPO_URL` supported)

## Related

- generacy-ai/tetrad-development#32 (same pattern: clone primary repo first, pass --config to setup workspace)
- #9 (worker crash loop — config conflict from duplicate clone compounds it)
- #7 (template placeholders)

---

*Generated by speckit*
