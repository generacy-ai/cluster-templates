# Tasks: Ensure speckit commands and Agency MCP are installed during onboarding

**Input**: Design documents from `/specs/004-problem-both-standard/`
**Prerequisites**: plan.md (required), spec.md (required), research.md (available)
**Status**: Complete

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Phase 1: Shared Setup Script

- [X] T001 [US1] Create `standard/.devcontainer/scripts/setup-speckit.sh` — new shared script that: (a) checks if `/workspaces/agency` exists, clones with retry if missing, (b) runs `npm install && npm run build` in agency if needed, (c) re-runs `generacy setup build` to trigger Phase 4, (d) provides `--verify` mode that checks `~/.claude/commands/specify.md` exists and `~/.claude/settings.json` contains agency MCP entry
- [X] T002 [P] [US1] Copy `setup-speckit.sh` to `microservices/.devcontainer/scripts/setup-speckit.sh` (identical copy)

## Phase 2: Error Handling & Pre-flight Checks

- [X] T003 [US2] Update `standard/.devcontainer/scripts/entrypoint-worker.sh` — replace `2>/dev/null || true` on all three generacy setup commands with selective error handling: auth logs warning, workspace logs warning, build triggers `setup-speckit.sh` recovery on failure; log errors to `/tmp/generacy-setup.log`
- [X] T004 [P] [US2] Update `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` — same error handling replacement as T003
- [X] T005 [P] [US2] Update `microservices/.devcontainer/scripts/entrypoint-worker.sh` — same error handling replacement as T003
- [X] T006 [P] [US2] Update `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` — same error handling replacement as T004
- [X] T007 [US3] Add pre-flight check to `standard/.devcontainer/scripts/entrypoint-worker.sh` — after setup, run `setup-speckit.sh --verify`; exit 1 with FATAL message if speckit not ready
- [X] T008 [P] [US3] Add pre-flight check to `microservices/.devcontainer/scripts/entrypoint-worker.sh` — same as T007
- [X] T009 [US3] Add light pre-flight warning to `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` — warn if speckit missing but don't block startup
- [X] T010 [P] [US3] Add light pre-flight warning to `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` — same as T009

## Phase 3: Validation

- [X] T011 Build validation — run `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/` and `docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/` to verify Dockerfiles still build

## Dependencies & Execution Order

1. **T001** must complete first (creates the shared script)
2. **T002** depends on T001 (copy of the script)
3. **T003–T006** can run in parallel (different files, same pattern) — depend on T001/T002
4. **T007–T010** can run in parallel (different files) — depend on T003–T006 respectively (error handling must be in place before adding pre-flight)
5. **T011** runs last (validates everything builds)

**Parallel opportunities**: T003+T004+T005+T006, T007+T008+T009+T010
