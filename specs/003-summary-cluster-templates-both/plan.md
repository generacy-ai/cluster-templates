# Implementation Plan: Fix Worker Entrypoint & Orchestrator Healthcheck

**Feature**: Update both cluster template variants to use the current orchestrator architecture
**Branch**: `003-summary-cluster-templates-both`
**Status**: Complete

## Summary

Two fixes across both `standard/` and `microservices/` template variants:

1. **Worker entrypoint**: Replace deprecated `generacy worker` CLI command with `generacy orchestrator --worker-only` (Redis-based polling instead of HTTP registration)
2. **Orchestrator healthcheck**: Change `/api/health` (authenticated, always returns 401) to `/health` (unauthenticated)
3. **Docker-compose env cleanup**: Remove stale env vars (`ORCHESTRATOR_URL`, `WORKDIR`) from worker services, ensure `REDIS_HOST`/`REDIS_PORT`/`HEALTH_PORT` are present

## Technical Context

- **Language/Runtime**: Bash (entrypoint scripts), YAML (docker-compose)
- **Dependencies**: Generacy CLI (`@generacy-ai/generacy@preview`), Redis 7
- **Reference implementation**: `generacy-ai/tetrad-development@1b3c01d`
- **Relevant PRs**: `generacy-ai/generacy#302` (worker command replaced), `generacy-ai/generacy#303` (maxConcurrentWorkers removed)

## Project Structure

```
cluster-templates/
├── standard/.devcontainer/
│   ├── docker-compose.yml          # FIX: orchestrator healthcheck, worker env vars
│   ├── scripts/
│   │   └── entrypoint-worker.sh    # FIX: replace `generacy worker` with `generacy orchestrator --worker-only`
│   ├── Dockerfile                  # NO CHANGES
│   └── devcontainer.json           # NO CHANGES
├── microservices/.devcontainer/
│   ├── docker-compose.yml          # FIX: orchestrator healthcheck, worker env vars
│   ├── scripts/
│   │   └── entrypoint-worker.sh    # FIX: replace `generacy worker` with `generacy orchestrator --worker-only`
│   ├── Dockerfile                  # NO CHANGES
│   └── devcontainer.json           # NO CHANGES
```

## Implementation Steps

### Step 1: Update worker entrypoint scripts

**Files**: `standard/.devcontainer/scripts/entrypoint-worker.sh`, `microservices/.devcontainer/scripts/entrypoint-worker.sh`

Replace the final `exec` block in both scripts:

```bash
# BEFORE (deprecated)
exec generacy worker \
    --worker-id "${AGENT_ID}" \
    --url "${ORCHESTRATOR_URL:-http://orchestrator:3100}" \
    --workdir "${WORKDIR:-/workspaces/project}" \
    --health-port "${HEALTH_PORT:-9001}"

# AFTER (current architecture)
exec generacy orchestrator \
    --port "${HEALTH_PORT:-9001}" \
    --redis-url "redis://${REDIS_HOST:-redis}:${REDIS_PORT:-6379}" \
    --worker-only
```

The new command:
- Uses `generacy orchestrator --worker-only` instead of `generacy worker`
- Connects directly to Redis (no HTTP registration with orchestrator)
- Drops `--worker-id` and `--workdir` flags (no longer needed)
- Keeps `--port` for the health endpoint on port 9001

### Step 2: Fix orchestrator healthcheck in docker-compose

**Files**: `standard/.devcontainer/docker-compose.yml`, `microservices/.devcontainer/docker-compose.yml`

Change the orchestrator service healthcheck:

```yaml
# BEFORE (authenticated — always fails)
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:${ORCHESTRATOR_PORT:-3100}/api/health"]

# AFTER (unauthenticated — works correctly)
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:${ORCHESTRATOR_PORT:-3100}/health"]
```

### Step 3: Clean up worker environment variables in docker-compose

**Files**: `standard/.devcontainer/docker-compose.yml`, `microservices/.devcontainer/docker-compose.yml`

In the worker service `environment` block:
- **Remove**: `ORCHESTRATOR_URL` (no longer used — workers poll Redis directly)
- **Keep**: `REDIS_URL`, `REDIS_HOST` (if not present, add `REDIS_HOST=redis`), `HEALTH_PORT=9001`
- **Keep**: `REPO_URL`, `REPO_BRANCH` (still used by git clone logic in entrypoint)

### Step 4: Validate Dockerfiles build

Run the build validation commands from CLAUDE.md:

```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

No Dockerfile changes are expected, but building confirms no broken COPY instructions.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Worker entrypoint flags differ from reference | Workers fail to start | Match tetrad-development reference exactly |
| Stale env vars break other tooling | Cluster setup fails | Only remove vars confirmed unused by new entrypoint |
| Healthcheck timing too aggressive | False unhealthy during startup | Keep existing `start_period: 60s` / `start_period: 90s` |

## Validation

Per the spec test plan:
1. Build both Dockerfiles (CI-level check)
2. Deploy standard template cluster — verify orchestrator healthy, worker picks up Redis jobs
3. Deploy microservices template cluster — same + DinD functionality
4. End-to-end: label an issue, confirm it queues and processes
