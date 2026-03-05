# Quickstart: Worker Entrypoint & Orchestrator Healthcheck Fix

## What Changed

1. **Worker entrypoint scripts** — `generacy worker` → `generacy orchestrator --worker-only`
2. **Orchestrator healthcheck** — `/api/health` → `/health`
3. **Worker env vars** — Removed stale `ORCHESTRATOR_URL`, ensured `REDIS_HOST`/`REDIS_PORT` present

## Files Modified

| File | Change |
|------|--------|
| `standard/.devcontainer/scripts/entrypoint-worker.sh` | New worker command |
| `microservices/.devcontainer/scripts/entrypoint-worker.sh` | New worker command |
| `standard/.devcontainer/docker-compose.yml` | Healthcheck path + env cleanup |
| `microservices/.devcontainer/docker-compose.yml` | Healthcheck path + env cleanup |

## Validation

### Build Dockerfiles

```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

### Deploy & Test

1. Start a cluster with either template
2. Verify orchestrator shows as **healthy**: `docker compose ps`
3. Verify workers connect to Redis and pick up jobs
4. Label a GitHub issue and confirm end-to-end processing

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Orchestrator shows `unhealthy` | Healthcheck still hitting `/api/health` | Ensure docker-compose uses `/health` |
| Worker exits immediately | Old `generacy worker` command | Ensure entrypoint uses `generacy orchestrator --worker-only` |
| Worker can't connect to Redis | Missing `REDIS_HOST` env var | Add `REDIS_HOST=redis` to worker environment in docker-compose |
