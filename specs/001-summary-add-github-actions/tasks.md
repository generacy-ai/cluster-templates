# Tasks: Add CI to Validate Dockerfiles Build Successfully

**Input**: `spec.md`, `plan.md`
**Prerequisites**: plan.md (required), spec.md (required)
**Status**: Ready

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup

### T001 [DONE] [US1] Create `.github/workflows/` directory structure
**File**: `.github/workflows/` (directory)
- Create the `.github/workflows/` directory (does not yet exist in the repo)
- This is the standard location for GitHub Actions workflow files

---

## Phase 2: Implementation

### T002 [DONE] [US1, US2, US3] Create CI workflow file
**File**: `.github/workflows/ci.yml`
- Define workflow name as `CI`
- Configure `on` triggers:
  - `push` to branches `[main, develop]`
  - `pull_request` to branches `[main, develop]`
- Define `validate` job with `ubuntu-latest` runner
- Configure matrix strategy with `variant: [standard, microservices]`
  - Use default `fail-fast: true`
- Set descriptive job name: `Validate ${{ matrix.variant }}`
- Add steps:
  1. **Checkout**: `actions/checkout@v4`
  2. **Build Dockerfile**: `docker build -f ${{ matrix.variant }}/.devcontainer/Dockerfile ${{ matrix.variant }}/.devcontainer/`
  3. **Validate Docker Compose config**: `docker compose -f ${{ matrix.variant }}/.devcontainer/docker-compose.yml config`
- Add stub environment variables on compose validation step only:
  - `REPO_URL: https://github.com/example/repo` (no default in compose files, required)
  - `REPO_BRANCH: main` (has `:-main` default but set explicitly for clarity)
- Note: `HOME` is available by default on GitHub runners; `ORCHESTRATOR_PORT`, `WORKER_COUNT` use `:-default` syntax in compose; `.env` file has `required: false`
- Do NOT use `--push`, `docker compose up`, or any container runtime commands (FR-010, FR-011)

---

## Phase 3: Local Validation

### T003 [DONE] [US1] Validate workflow YAML syntax
**File**: `.github/workflows/ci.yml`
- Verify the YAML file is syntactically valid (parse with a YAML linter or manual review)
- Confirm all GitHub Actions workflow keys are correct (`name`, `on`, `jobs`, `strategy`, `matrix`, `steps`)
- Verify `actions/checkout@v4` is pinned to a specific major version

### T004 [DONE] [P] [US1] Validate Dockerfile builds locally (standard)
**File**: `standard/.devcontainer/Dockerfile`
- Run `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/` locally
- Confirm it completes without errors
- Verify the build context path matches the workflow step

### T005 [DONE] [P] [US1] Validate Dockerfile builds locally (microservices)
**File**: `microservices/.devcontainer/Dockerfile`
- Run `docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/` locally
- Confirm it completes without errors
- Verify the build context path matches the workflow step

### T006 [DONE] [P] [US2] Validate Docker Compose config locally (standard)
**File**: `standard/.devcontainer/docker-compose.yml`
- Run with stub env vars: `REPO_URL=https://github.com/example/repo REPO_BRANCH=main docker compose -f standard/.devcontainer/docker-compose.yml config`
- Confirm it outputs the resolved config without errors
- Verify `${HOME}/.claude.json` bind mount doesn't cause config validation failure

### T007 [DONE] [P] [US2] Validate Docker Compose config locally (microservices)
**File**: `microservices/.devcontainer/docker-compose.yml`
- Run with stub env vars: `REPO_URL=https://github.com/example/repo REPO_BRANCH=main docker compose -f microservices/.devcontainer/docker-compose.yml config`
- Confirm it outputs the resolved config without errors
- Verify `${HOME}/.claude.json` bind mount doesn't cause config validation failure

---

## Phase 4: Verification

### T008 [DONE] [US3] Review matrix naming and CI output clarity
**File**: `.github/workflows/ci.yml`
- Confirm job name template `Validate ${{ matrix.variant }}` will render as "Validate standard" and "Validate microservices" in Actions UI
- Verify each step has a descriptive `name` field so build and compose validation output are clearly separated in logs
- Confirm no `> /dev/null` or output suppression that would hide error details

### T009 [DONE] [US1, US2] Cross-reference spec acceptance criteria
**Files**:
- `.github/workflows/ci.yml`
- `specs/001-summary-add-github-actions/spec.md`
- Verify all functional requirements FR-001 through FR-011 are addressed:
  - FR-001: Single workflow file exists at `.github/workflows/ci.yml`
  - FR-002: Push trigger on `main` and `develop`
  - FR-003: PR trigger on `main` and `develop`
  - FR-004/005: Both Dockerfiles built with `docker build`
  - FR-006/007: Both compose files validated with `docker compose config`
  - FR-008: Stub env vars provided (`REPO_URL`, `REPO_BRANCH`)
  - FR-009: Matrix strategy with `[standard, microservices]`
  - FR-010: No `--push` flag
  - FR-011: No `docker compose up` or container execution

---

## Dependencies & Execution Order

**Phase dependencies (sequential)**:
- Phase 1 (Setup) must complete before Phase 2 (Implementation)
- Phase 2 (Implementation) must complete before Phase 3 (Local Validation)
- Phase 3 (Local Validation) must complete before Phase 4 (Verification)

**Parallel opportunities within phases**:
- T004, T005 can run in parallel (independent Dockerfile builds)
- T006, T007 can run in parallel (independent compose validations)
- T004/T005 and T006/T007 can also run in parallel across groups

**Critical path**:
T001 → T002 → T003 → T004/T005/T006/T007 (parallel) → T008 → T009
