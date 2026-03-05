# Clarifications

Questions and answers to clarify the feature specification.

## Batch 1 - 2026-03-05 20:48

### Q1: Healthcheck endpoint path
**Context**: The spec lists two options for fixing the orchestrator healthcheck (unauthenticated endpoint vs. passing credentials) but doesn't specify which to use. Since adding a new endpoint to the orchestrator CLI is out of scope, we need to know what unauthenticated endpoint already exists in the Fastify orchestrator.
**Question**: What is the correct unauthenticated health endpoint path on the Fastify orchestrator? Is it `/health`, `/healthz`, or something else? If no unauthenticated endpoint currently exists, should we use a different check method (e.g., TCP port check instead of HTTP)?
**Options**:
- A: `/health` — unauthenticated root-level health endpoint exists
- B: `/healthz` — Kubernetes-style health endpoint exists
- C: TCP check — use `curl -f http://localhost:PORT/` or a simple port check instead of an HTTP health endpoint
- D: Other — a different endpoint or approach is needed

**Answer**: A — `/health` is the correct unauthenticated endpoint. The reference implementation in tetrad-development uses `http://localhost:3100/health` for the orchestrator healthcheck.

### Q2: Docker-compose env var cleanup
**Context**: The current worker service in docker-compose likely sets environment variables like `ORCHESTRATOR_URL` and `WORKDIR` that are no longer needed by the new `generacy orchestrator --worker-only` command. Leaving stale env vars is confusing for operators; removing them could break other scripts.
**Question**: Should we remove environment variables from docker-compose worker services that are no longer used by the new entrypoint (e.g., `ORCHESTRATOR_URL`, `WORKDIR`), or leave them for backward compatibility?
**Options**:
- A: Remove stale env vars (`ORCHESTRATOR_URL`, `WORKDIR`) and add new ones (`REDIS_HOST`, `REDIS_PORT`) if not already present
- B: Keep all existing env vars and just add any new ones needed
- C: Only change the entrypoint scripts; don't touch docker-compose env vars at all

**Answer**: A — Remove stale env vars and add the new ones. The reference worker service in tetrad-development uses `REDIS_URL`, `REDIS_HOST`, and `HEALTH_PORT` with no `ORCHESTRATOR_URL` or `WORKDIR`.
