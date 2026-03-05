# Feature Specification: Update worker entrypoints and orchestrator healthcheck for Fastify orchestrator

The cluster-templates (both `standard/` and `microservices/` variants) need to be updated to align with the current generacy orchestrator architecture.

**Branch**: `003-summary-cluster-templates-both` | **Date**: 2026-03-05 | **Status**: Draft | **Issue**: [#3](https://github.com/generacy-ai/cluster-templates/issues/3)

## Summary

The cluster-templates (both `standard/` and `microservices/` variants) need to be updated to align with the current generacy orchestrator architecture. There are two issues:

### 1. Worker entrypoint uses deprecated `generacy worker` CLI command

Both templates currently use the old HTTP-based worker command:

```bash
# current (BROKEN) — standard/.devcontainer/scripts/entrypoint-worker.sh
# current (BROKEN) — microservices/.devcontainer/scripts/entrypoint-worker.sh
exec generacy worker \
    --worker-id "${AGENT_ID}" \
    --url "${ORCHESTRATOR_URL:-http://orchestrator:3100}" \
    --workdir "${WORKDIR:-/workspaces/project}" \
    --health-port "${HEALTH_PORT:-9001}"
```

The `generacy worker` command is deprecated. Workers now use the Fastify-based orchestrator in `--worker-only` mode, polling Redis directly instead of registering with the orchestrator over HTTP. The working entrypoint from tetrad-development is:

```bash
# correct — tetrad-development/.devcontainer/entrypoint-generacy-worker.sh
exec generacy orchestrator \
    --port "${HEALTH_PORT:-9001}" \
    --redis-url "redis://${REDIS_HOST:-redis}:${REDIS_PORT:-6379}" \
    --worker-only
```

**Files to update:**
- `standard/.devcontainer/scripts/entrypoint-worker.sh`
- `microservices/.devcontainer/scripts/entrypoint-worker.sh`

### 2. Orchestrator healthcheck endpoint returns 401 Unauthorized

Both docker-compose files use `/api/health` for the orchestrator healthcheck:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:${ORCHESTRATOR_PORT:-3100}/api/health"]
```

The `/api/health` endpoint requires authentication, so the healthcheck always fails and Docker marks the orchestrator as `unhealthy`. The worker healthcheck (`/health` on port 9001) works fine because it's unauthenticated.

This needs either:
- An unauthenticated health endpoint on the orchestrator (e.g. `/health` outside the `/api` prefix), or
- The healthcheck updated to pass credentials

**Files to update:**
- `standard/.devcontainer/docker-compose.yml`
- `microservices/.devcontainer/docker-compose.yml`

## Context

- tetrad-development entrypoints are the reference implementation: `generacy-ai/tetrad-development@1b3c01d`
- The old `generacy worker` command was replaced by `generacy orchestrator --worker-only` in `generacy-ai/generacy#302`
- The `maxConcurrentWorkers` config was removed in `generacy-ai/generacy#303` — each worker container now processes exactly one job at a time; scaling is via container replicas

## Test plan

- [ ] Deploy a cluster using the standard template — verify orchestrator shows as healthy, worker picks up jobs from Redis
- [ ] Deploy a cluster using the microservices template — same verification plus DinD functionality
- [ ] Label an issue and confirm it gets queued and processed end-to-end

## User Stories

### US1: External developer onboarding with working cluster

**As an** external developer onboarding to Generacy,
**I want** the cluster templates to start correctly with healthy orchestrator and workers,
**So that** I can begin development without debugging infrastructure issues.

**Acceptance Criteria**:
- [ ] Worker containers start and poll Redis for jobs using `generacy orchestrator --worker-only`
- [ ] Orchestrator container healthcheck passes (Docker reports "healthy")
- [ ] End-to-end job processing works: label an issue → job queued → worker picks it up

### US2: Cluster operator scaling workers

**As a** cluster operator,
**I want** each worker container to process one job at a time with scaling via replicas,
**So that** I can scale the cluster predictably by adjusting container count.

**Acceptance Criteria**:
- [ ] Workers no longer accept `--worker-id` or `--url` flags (deprecated CLI removed)
- [ ] Workers connect directly to Redis, not to the orchestrator HTTP API
- [ ] Multiple worker replicas can run simultaneously without conflict

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Replace `generacy worker` command with `generacy orchestrator --worker-only` in both variant entrypoints | P0 | Deprecated CLI, workers are currently broken |
| FR-002 | Update worker entrypoint flags: `--port`, `--redis-url`, `--worker-only` | P0 | Reference: tetrad-development entrypoint |
| FR-003 | Fix orchestrator healthcheck endpoint to use an unauthenticated path | P0 | `/api/health` requires auth, causes perpetual "unhealthy" |
| FR-004 | Ensure both `standard/` and `microservices/` variants receive identical fixes | P1 | Consistency across templates |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | Orchestrator health status | "healthy" in `docker ps` | Deploy cluster, check container status |
| SC-002 | Worker job processing | Jobs picked up from Redis | Label an issue, verify worker processes it |
| SC-003 | Both variants working | 2/2 templates functional | Deploy each variant and run test plan |

## Assumptions

- The `generacy orchestrator --worker-only` command is available in the generacy CLI version used by these templates
- Redis is available at `redis://redis:6379` as configured in the docker-compose files
- The orchestrator Fastify server exposes an unauthenticated health endpoint (or one can be added outside `/api` prefix)

## Out of Scope

- Changes to the generacy CLI itself (this only updates the templates)
- Adding new services or capabilities to the cluster templates
- Modifying the `maxConcurrentWorkers` config (already removed upstream)

---

*Generated by speckit*
