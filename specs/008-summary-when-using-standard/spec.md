# Feature Specification: Eliminate duplicate repo clone in devcontainer mode

**Branch**: `008-summary-when-using-standard` | **Date**: 2026-03-07 | **Status**: Draft | **Issue**: [#8](https://github.com/generacy-ai/cluster-templates/issues/8)

## Summary

When using the standard template with VS Code Dev Containers, the project repo gets cloned twice — once by the Dev Containers extension (to `/workspaces/<repo-name>`) and again by the entrypoint scripts (to `/workspaces/project`). This wastes disk space and causes config file conflicts.

Additionally, after cloning the primary repo, the entrypoint should pass `--config` to `generacy setup workspace` so it can discover the `.generacy/config.yaml` and clone additional repos listed there.

## Problem

Both `entrypoint-orchestrator.sh` (lines 15-24) and `entrypoint-worker.sh` (lines 17-25) unconditionally clone `REPO_URL` to `/workspaces/project`:

```bash
if [ -n "${REPO_URL:-}" ] && [ ! -d "/workspaces/project/.git" ]; then
    git clone --branch "${REPO_BRANCH:-main}" "${REPO_URL}" /workspaces/project
```

When opened via VS Code Dev Containers, the extension has already cloned the repo to `/workspaces/<repo-name>` (e.g., `/workspaces/markdown-preview-tool`). This results in:

1. **Two copies of the repo** — `/workspaces/markdown-preview-tool` and `/workspaces/project`
2. **Config file conflicts** — `generacy setup workspace` finds multiple `.generacy/config.yaml` files:
   ```
   ERROR (generacy): Multiple .generacy/config.yaml files found. Use --config or CONFIG_PATH to specify which one.
     configs: [
       "/workspaces/markdown-preview-tool/.generacy/config.yaml",
       "/workspaces/project/.generacy/config.yaml"
     ]
   ```
3. **Worker setup failures cascade** — The config conflict causes `generacy setup workspace` to fail, which feeds into the worker crash loop

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

After cloning the primary repo, the entrypoint should pass the config path explicitly so `generacy setup workspace` can discover and clone additional repos:

```bash
CONFIG_PATH="${WORKSPACE_DIR}/.generacy/config.yaml"
if [ -f "$CONFIG_PATH" ]; then
    generacy setup workspace --config "$CONFIG_PATH"
else
    generacy setup workspace
fi
```

This is the same pattern needed in generacy-ai/tetrad-development#32.

### 4. Add WORKSPACE_DIR to .env.template

```env
# Workspace directory override (default: derived from REPO_URL)
# WORKSPACE_DIR=/workspaces/my-project
```

## Files Affected

- `.devcontainer/scripts/entrypoint-orchestrator.sh` — derive clone path, add devcontainer detection, pass --config
- `.devcontainer/scripts/entrypoint-worker.sh` — same changes
- `.devcontainer/.env.template` — add `WORKSPACE_DIR`
- `.devcontainer/docker-compose.yml` — pass `WORKSPACE_DIR` to environment

## Related

- generacy-ai/tetrad-development#32 (same pattern: clone primary repo first, pass --config to setup workspace)
- #9 (worker crash loop — config conflict from duplicate clone compounds it)
- #7 (template placeholders)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## User Stories

### US1: Devcontainer developer avoids duplicate clone

**As a** developer using VS Code Dev Containers,
**I want** the entrypoint scripts to detect the already-cloned repo and skip re-cloning,
**So that** I don't waste disk space or hit config file conflicts from duplicate `.generacy/config.yaml` files.

**Acceptance Criteria**:
- [ ] When opened via VS Code Dev Containers, the repo is not cloned a second time to `/workspaces/project`
- [ ] `generacy setup workspace` runs without "Multiple .generacy/config.yaml" errors
- [ ] Workers start successfully without cascading failures from config conflicts

### US2: Docker Compose user gets correct workspace path

**As a** developer running the cluster via `docker compose up` (non-devcontainer),
**I want** the repo cloned to `/workspaces/<repo-name>` instead of `/workspaces/project`,
**So that** the workspace path is predictable and consistent with devcontainer mode.

**Acceptance Criteria**:
- [ ] Repo is cloned to `/workspaces/<repo-name>` derived from `REPO_URL`
- [ ] `WORKSPACE_DIR` env var can override the default derived path
- [ ] `--config` is passed to `generacy setup workspace` when `.generacy/config.yaml` exists

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Derive clone path from `REPO_URL` instead of hardcoding `/workspaces/project` | P1 | Both orchestrator and worker entrypoints |
| FR-002 | Detect devcontainer mode and skip clone if repo already exists | P1 | Check `DEVCONTAINER` or `REMOTE_CONTAINERS` env vars |
| FR-003 | Pass `--config` to `generacy setup workspace` when config file exists | P1 | Prevents "multiple config" errors |
| FR-004 | Add `WORKSPACE_DIR` to `.env.template` and `docker-compose.yml` | P2 | Allow manual override of workspace path |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | Duplicate repo copies | 0 | Only one copy of the repo exists in `/workspaces/` after startup |
| SC-002 | Config conflict errors | 0 | `generacy setup workspace` completes without "Multiple config" errors |
| SC-003 | Worker startup success | 100% | Workers start without cascading failures from config issues |

## Assumptions

- VS Code Dev Containers extension sets `DEVCONTAINER` or `REMOTE_CONTAINERS` environment variable
- The repo URL follows standard Git URL conventions (ends with `.git` or bare repo name)
- Both `standard/` and `microservices/` variants share the same entrypoint script structure

## Out of Scope

- Changes to the `generacy` CLI itself (config resolution logic)
- Multi-repo workspace support beyond what `generacy setup workspace --config` provides
- Fixing the worker crash loop (#9) beyond eliminating the config conflict trigger

---

*Generated by speckit*
