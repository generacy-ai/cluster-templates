# Tasks: Port Shared Volume Package Install Approach with Release Channels

**Input**: Design documents from `/specs/012-summary-adopt-shared-volume/`
**Prerequisites**: plan.md (required), spec.md (required)
**Status**: Complete

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Phase 1: Docker Image & Compose Infrastructure

- [ ] T001 [US1] Read `standard/.devcontainer/Dockerfile` and remove the `npm install -g @generacy-ai/generacy@preview @generacy-ai/agency@preview` line from the tooling stage
- [ ] T002 [P] [US1] Read `microservices/.devcontainer/Dockerfile` and remove the `npm install -g @generacy-ai/generacy@preview @generacy-ai/agency@preview` line from the tooling stage
- [ ] T003 [US1] Read `standard/.devcontainer/docker-compose.yml` and add `shared-packages` and `npm-cache` named volumes; mount `shared-packages:/shared-packages` (rw) and `npm-cache:/home/node/.npm` on orchestrator; mount `shared-packages:/shared-packages:ro` on worker; add `GENERACY_CHANNEL` and `SKIP_PACKAGE_UPDATE` env vars to orchestrator and worker
- [ ] T004 [P] [US1] Read `microservices/.devcontainer/docker-compose.yml` and apply identical volume and env var changes as T003

## Phase 2: Orchestrator Entrypoint — npm Install Logic

- [ ] T005 [US1] [US2] [US3] Read `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` and insert the package install block (with `install_packages` function, skip-if-SKIP_PACKAGE_UPDATE logic, version-match marker file check at `/shared-packages/.installed-version`, and `export PATH="/shared-packages/node_modules/.bin:${PATH}"`) before the `generacy setup` calls
- [ ] T006 [P] [US1] [US2] [US3] Read `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` and apply identical orchestrator entrypoint changes as T005

## Phase 3: Worker Entrypoint — Wrapper Scripts & PATH

- [ ] T007 [US1] Read `standard/.devcontainer/scripts/entrypoint-worker.sh` and insert the wrapper script block early in the entrypoint: create `~/.local/bin/generacy` and `~/.local/bin/agency` wrapper scripts pointing to `/shared-packages/node_modules/.bin/`; add `export PATH="${LOCAL_BIN}:${PATH}"` and append to `~/.bashrc`
- [ ] T008 [P] [US1] Read `microservices/.devcontainer/scripts/entrypoint-worker.sh` and apply identical worker entrypoint changes as T007

## Phase 4: setup-speckit.sh Recovery Path

- [ ] T009 [US4] Read `standard/.devcontainer/scripts/setup-speckit.sh` and replace the git clone + build fallback with `npm install -g @generacy-ai/agency-plugin-spec-kit` followed by `generacy setup build`; remove `AGENCY_REPO_URL`, `AGENCY_DIR`, `clone_with_retry` function, and the cloned-repo build step
- [ ] T010 [P] [US4] Read `microservices/.devcontainer/scripts/setup-speckit.sh` and apply identical setup-speckit.sh changes as T009

## Phase 5: Validation

- [ ] T011 Build `standard/.devcontainer/Dockerfile` to verify it compiles cleanly: `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/`
- [ ] T012 [P] Build `microservices/.devcontainer/Dockerfile` to verify it compiles cleanly: `docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/`

## Dependencies & Execution Order

**Phase ordering** (sequential between phases):
- Phase 1 (infrastructure) must complete before Phases 2–4 (scripts depend on volumes being defined)
- Phases 2, 3, and 4 are independent of each other and can run in parallel across variants
- Phase 5 (validation) requires all prior phases complete

**Parallel opportunities within phases**:
- T001 and T002 can run in parallel (different Dockerfiles)
- T003 and T004 can run in parallel (different docker-compose files)
- T005 and T006 can run in parallel (different variants, same changes)
- T007 and T008 can run in parallel (different variants, same changes)
- T009 and T010 can run in parallel (different variants, same changes)
- T011 and T012 can run in parallel (independent Docker builds)

**Variant parity**: Every change in `standard/` has an exact mirror in `microservices/` — always apply both to keep variants in sync.
