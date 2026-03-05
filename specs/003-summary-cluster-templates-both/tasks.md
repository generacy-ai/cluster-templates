# Tasks: Fix Worker Entrypoint & Orchestrator Healthcheck

**Input**: Design documents from `/specs/003-summary-cluster-templates-both/`
**Prerequisites**: plan.md (required), spec.md (required), research.md (available)
**Status**: Complete

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Phase 1: Worker Entrypoint Fix

- [ ] T001 [P] Update `standard/.devcontainer/scripts/entrypoint-worker.sh` — replace `exec generacy worker ...` block with `exec generacy orchestrator --port "${HEALTH_PORT:-9001}" --redis-url "redis://${REDIS_HOST:-redis}:${REDIS_PORT:-6379}" --worker-only`
- [ ] T002 [P] Update `microservices/.devcontainer/scripts/entrypoint-worker.sh` — same replacement as T001

## Phase 2: Docker Compose Fixes

- [ ] T003 [P] Fix orchestrator healthcheck in `standard/.devcontainer/docker-compose.yml` — change `/api/health` to `/health` in the orchestrator service healthcheck
- [ ] T004 [P] Fix orchestrator healthcheck in `microservices/.devcontainer/docker-compose.yml` — same change as T003
- [ ] T005 [P] Clean up worker env vars in `standard/.devcontainer/docker-compose.yml` — remove `ORCHESTRATOR_URL`, ensure `REDIS_HOST=redis` and `HEALTH_PORT=9001` are present
- [ ] T006 [P] Clean up worker env vars in `microservices/.devcontainer/docker-compose.yml` — same cleanup as T005

## Phase 3: Validation

- [ ] T007 Build standard Dockerfile: `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/`
- [ ] T008 Build microservices Dockerfile: `docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/`

## Dependencies & Execution Order

- **Phase 1** (T001, T002): Independent — both entrypoint scripts can be updated in parallel
- **Phase 2** (T003–T006): Independent of each other, but logically grouped after Phase 1 since they touch the same variants
- **Phase 3** (T007, T008): Must run after Phases 1–2 to validate the final state; both builds can run in parallel
- All tasks within each phase are marked `[P]` (parallelizable)
