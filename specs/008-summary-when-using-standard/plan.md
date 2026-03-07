# Implementation Plan: Eliminate duplicate repo clone in devcontainer mode

**Feature**: Fix duplicate repo clone when using standard template with VS Code Dev Containers
**Branch**: `008-summary-when-using-standard`
**Status**: Complete
**Issue**: #8

## Summary

Modify both entrypoint scripts (orchestrator and worker) to:
1. Derive the clone path from `REPO_URL` instead of hardcoding `/workspaces/project`
2. Detect devcontainer mode and skip cloning when the repo already exists
3. Pass `--config` to `generacy setup workspace` when `.generacy/config.yaml` exists
4. Support `WORKSPACE_DIR` env var override via `.env.template` and `docker-compose.yml`

## Technical Context

- **Language**: Bash (shell scripts)
- **Runtime**: Docker containers (Debian-based, node user)
- **Dependencies**: git, generacy CLI, nc (netcat)
- **Variants**: Standard and Microservices (pending clarification Q1 — plan covers both assuming "apply to both")

## Pending Clarifications

Three clarifications (Q1–Q3 in `clarifications.md`) are still pending. The plan proceeds with these assumptions:
- **Q1 (Microservices scope)**: Assume both variants — changes are identical except microservices adds `setup-docker-dind.sh`
- **Q2 (Multiple repos detection)**: Assume match by `REPO_URL` basename — more reliable than `head -1`
- **Q3 (Backwards compat)**: Assume no external dependencies on `/workspaces/project` — safe to change

## Project Structure

```
standard/.devcontainer/
├── scripts/
│   ├── entrypoint-orchestrator.sh  ← MODIFY (clone logic, devcontainer detection, --config)
│   └── entrypoint-worker.sh        ← MODIFY (same changes)
├── docker-compose.yml               ← MODIFY (add WORKSPACE_DIR env var)
├── .env.template                    ← CREATE (new file with WORKSPACE_DIR)
└── ...

microservices/.devcontainer/
├── scripts/
│   ├── entrypoint-orchestrator.sh  ← MODIFY (same changes)
│   └── entrypoint-worker.sh        ← MODIFY (same changes)
├── docker-compose.yml               ← MODIFY (add WORKSPACE_DIR env var)
├── .env.template                    ← CREATE (new file with WORKSPACE_DIR)
└── ...
```

## Implementation Steps

### Step 1: Extract shared clone/detect logic into a helper function

Both entrypoint scripts (orchestrator + worker) share identical clone logic (lines 14–23). Rather than duplicating the fix in 4 files, extract a shared `resolve-workspace.sh` helper that:

1. Accepts `REPO_URL`, `REPO_BRANCH`, and optional `WORKSPACE_DIR` override
2. Derives `WORKSPACE_DIR` from `REPO_URL` basename if not set
3. Detects devcontainer mode (`DEVCONTAINER` or `REMOTE_CONTAINERS` env vars)
4. In devcontainer mode: checks if `/workspaces/<repo-name>/.git` exists, uses it if so
5. In standalone mode: clones to `WORKSPACE_DIR` if not already cloned, else pulls latest
6. Exports `WORKSPACE_DIR` for downstream use

**File**: `standard/.devcontainer/scripts/resolve-workspace.sh` (new)
**File**: `microservices/.devcontainer/scripts/resolve-workspace.sh` (new, identical)

### Step 2: Update entrypoint scripts to use the helper

Replace the inline clone block (lines 14–23) in each entrypoint with:

```bash
# Resolve workspace directory (handles devcontainer detection + clone)
source /usr/local/bin/resolve-workspace.sh
```

Then update the `generacy setup workspace` call to pass `--config`:

```bash
CONFIG_PATH="${WORKSPACE_DIR}/.generacy/config.yaml"
if [ -f "$CONFIG_PATH" ]; then
    generacy setup workspace --config "$CONFIG_PATH" --clean 2>>"$SETUP_LOG" || ...
else
    generacy setup workspace --clean 2>>"$SETUP_LOG" || ...
fi
```

**Files modified** (4 total):
- `standard/.devcontainer/scripts/entrypoint-orchestrator.sh`
- `standard/.devcontainer/scripts/entrypoint-worker.sh`
- `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh`
- `microservices/.devcontainer/scripts/entrypoint-worker.sh`

### Step 3: Add WORKSPACE_DIR to docker-compose.yml

Add `WORKSPACE_DIR` to the environment section for both orchestrator and worker services:

```yaml
environment:
  - WORKSPACE_DIR=${WORKSPACE_DIR:-}
```

**Files modified** (2 total):
- `standard/.devcontainer/docker-compose.yml`
- `microservices/.devcontainer/docker-compose.yml`

### Step 4: Create .env.template

Create `.env.template` with documented env vars including the new `WORKSPACE_DIR`:

```env
# Workspace directory override (default: derived from REPO_URL)
# WORKSPACE_DIR=/workspaces/my-project
```

**Files created** (2 total):
- `standard/.devcontainer/.env.template`
- `microservices/.devcontainer/.env.template`

### Step 5: Update Dockerfiles to copy the new helper script

Add `COPY scripts/resolve-workspace.sh /usr/local/bin/resolve-workspace.sh` to both Dockerfiles, alongside the existing entrypoint script copies.

**Files modified** (2 total):
- `standard/.devcontainer/Dockerfile`
- `microservices/.devcontainer/Dockerfile`

### Step 6: Validate with Docker build

Run the validation builds per CLAUDE.md:

```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shared helper vs inline fix | Shared `resolve-workspace.sh` | Avoids duplicating logic across 4 files; single source of truth |
| Devcontainer detection | Check `DEVCONTAINER` / `REMOTE_CONTAINERS` env vars | Standard env vars set by VS Code Dev Containers extension |
| Repo matching in devcontainer mode | Match by `REPO_URL` basename | More reliable than `head -1` when multiple repos exist |
| Clone path derivation | `basename "${REPO_URL%.git}"` | Handles both `.git` and non-`.git` URLs |
| `--config` flag | Conditional on file existence | Graceful fallback when no `.generacy/config.yaml` present |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| `DEVCONTAINER` env var not set by extension | Devcontainer detection fails, clone proceeds normally | Fallback is the current behavior — no regression |
| `REPO_URL` basename doesn't match devcontainer clone path | Clone skipping fails, duplicate clone occurs | Match logic uses same derivation as standalone mode |
| Existing setups reference `/workspaces/project` | Broken paths | Pending clarification Q3; `WORKSPACE_DIR` override available as escape hatch |

## Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `standard/.devcontainer/scripts/resolve-workspace.sh` | Create | Shared workspace resolution helper |
| `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` | Modify | Use helper, add --config |
| `standard/.devcontainer/scripts/entrypoint-worker.sh` | Modify | Use helper, add --config |
| `standard/.devcontainer/docker-compose.yml` | Modify | Add WORKSPACE_DIR env |
| `standard/.devcontainer/.env.template` | Create | Document WORKSPACE_DIR |
| `standard/.devcontainer/Dockerfile` | Modify | Copy resolve-workspace.sh |
| `microservices/.devcontainer/scripts/resolve-workspace.sh` | Create | Same helper |
| `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` | Modify | Use helper, add --config |
| `microservices/.devcontainer/scripts/entrypoint-worker.sh` | Modify | Use helper, add --config |
| `microservices/.devcontainer/docker-compose.yml` | Modify | Add WORKSPACE_DIR env |
| `microservices/.devcontainer/.env.template` | Create | Document WORKSPACE_DIR |
| `microservices/.devcontainer/Dockerfile` | Modify | Copy resolve-workspace.sh |

---

*Generated by speckit*
