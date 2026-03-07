# Tasks: Template Placeholders and .env Split

**Input**: Design documents from `/specs/007-summary-when-external-projects/`
**Prerequisites**: plan.md (required), spec.md (required), research.md (available)
**Status**: Complete

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Phase 1: .env File Split

- [X] T001 [P] [US2] Split `standard/.devcontainer/.env.template` into `.env` (project config with `{{PROJECT_NAME}}`, `{{REPO_URL}}` placeholders) and `.env.local.template` (secrets: GH_TOKEN, GH_USERNAME, GH_EMAIL, CLAUDE_API_KEY)
- [X] T002 [P] [US2] Split `microservices/.devcontainer/.env.template` into `.env` and `.env.local.template` (same structure as standard)
- [X] T003 [US2] Create `.gitignore` at repo root with `.env.local` entry

## Phase 2: Template Placeholders in Compose Files

- [X] T004 [P] [US1] Update `standard/.devcontainer/docker-compose.yml` — add top-level `name: {{PROJECT_NAME}}`, update `env_file:` to load both `.env` and `.env.local` (required: false)
- [X] T005 [P] [US1] Update `microservices/.devcontainer/docker-compose.yml` — add top-level `name: {{PROJECT_NAME}}`, update `env_file:` to load both `.env` and `.env.local` (required: false)

## Phase 3: Template Placeholders in devcontainer.json

- [X] T006 [P] [US1] Update `standard/.devcontainer/devcontainer.json` — change `"name"` from `"Generacy Development Cluster"` to `"{{PROJECT_NAME}}"`, change `"workspaceFolder"` from `"/workspaces"` to `"/workspaces/{{REPO_NAME}}"`
- [X] T007 [P] [US1] Update `microservices/.devcontainer/devcontainer.json` — change `"name"` from `"Generacy Development Cluster (Microservices)"` to `"{{PROJECT_NAME}}"`, change `"workspaceFolder"` from `"/workspaces"` to `"/workspaces/{{REPO_NAME}}"`

## Phase 4: Initialization Script

- [X] T008 [US1] Create `init-template.sh` at repo root with:
  - Argument parsing: `--name <project-name>`, `--repo <repo-url>`, `--variant standard|microservices` (default: standard), `--repo-name <name>` (optional)
  - Interactive prompts as fallback for required args
  - Auto-derive `REPO_NAME` from `REPO_URL` via `basename "$REPO_URL" .git`
  - Input validation (non-empty project name, non-empty repo URL)
  - `sed -i.bak` replacement of `{{PROJECT_NAME}}` and `{{REPO_NAME}}` in target files (`docker-compose.yml`, `devcontainer.json`, `.env`)
  - Portable sed (create .bak then remove, works on GNU and BSD)
  - Print summary of changes
  - Make executable (`chmod +x`)

## Phase 5: Validation

- [X] T009 [US3] Verify both variants build: `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/` and `docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/` after running init-template.sh with test values
- [X] T010 [US1] Verify placeholder replacement is complete: `grep -r '{{' standard/ microservices/` returns no matches after initialization

## Dependencies & Execution Order

- **Phase 1** (T001-T003): No internal dependencies. T001 and T002 are parallel. T003 is independent.
- **Phase 2** (T004-T005): Depends on Phase 1 (needs `.env` files to exist for `env_file:` references). T004 and T005 are parallel.
- **Phase 3** (T006-T007): No dependency on Phase 2, but logically grouped after compose changes. T006 and T007 are parallel.
- **Phase 4** (T008): Depends on Phases 1-3 (all placeholder files must exist before the init script can target them).
- **Phase 5** (T009-T010): Depends on Phase 4 (requires init script to run validation).

**Parallel opportunities**: T001+T002, T004+T005, T006+T007 can each run concurrently within their phases.
