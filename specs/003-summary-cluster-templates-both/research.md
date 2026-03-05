# Research: Worker Entrypoint & Orchestrator Healthcheck Fix

## Technology Decisions

### 1. Worker command: `generacy orchestrator --worker-only`

**Decision**: Replace `generacy worker` with `generacy orchestrator --worker-only`

**Rationale**: The `generacy worker` CLI command was deprecated in `generacy-ai/generacy#302`. Workers now run the same Fastify-based orchestrator binary in a special `--worker-only` mode that:
- Polls Redis directly for jobs (no HTTP registration with orchestrator)
- Processes exactly one job at a time (scaling is via container replicas, per `generacy-ai/generacy#303`)
- Exposes a lightweight `/health` endpoint on the configured port

**Reference**: `generacy-ai/tetrad-development@1b3c01d` — `entrypoint-generacy-worker.sh`

### 2. Healthcheck endpoint: `/health` (unauthenticated)

**Decision**: Use `/health` instead of `/api/health`

**Rationale**: The Fastify orchestrator mounts authenticated routes under `/api/*`. The `/health` endpoint is at the root level and does not require authentication, making it suitable for Docker healthchecks.

**Alternatives considered**:
- **Pass credentials in healthcheck**: Rejected — adds complexity, requires secrets in docker-compose healthcheck command
- **TCP port check**: Rejected — `/health` endpoint exists and provides richer status info
- **`/healthz` (k8s-style)**: Not implemented in the orchestrator; `/health` is the actual endpoint

### 3. Environment variable cleanup

**Decision**: Remove `ORCHESTRATOR_URL` from worker services, keep `REDIS_URL`/`REDIS_HOST`

**Rationale**: Per clarification Q2 answer, the reference implementation uses `REDIS_URL`, `REDIS_HOST`, and `HEALTH_PORT` with no `ORCHESTRATOR_URL` or `WORKDIR`. Stale env vars are confusing for operators.

## Implementation Patterns

- **Entrypoint pattern**: Both variants use the same `exec generacy orchestrator --worker-only` pattern; the microservices variant adds DinD setup before the exec
- **Env var interpolation**: Entrypoint scripts use shell parameter expansion (`${VAR:-default}`) for all configurable values
- **Healthcheck pattern**: Docker Compose `CMD` form with `curl -f` for HTTP health endpoints, `redis-cli ping` for Redis

## Key Sources

- Spec: `specs/003-summary-cluster-templates-both/spec.md`
- Clarifications: `specs/003-summary-cluster-templates-both/clarifications.md`
- Reference implementation: `generacy-ai/tetrad-development@1b3c01d`
- Deprecation PR: `generacy-ai/generacy#302`
- Scaling change PR: `generacy-ai/generacy#303`
