# Feature Specification: Template Placeholders and .env Split for Project-Specific Configuration

**Branch**: `007-summary-when-external-projects` | **Date**: 2026-03-07 | **Status**: Draft | **Issue**: [#7](https://github.com/generacy-ai/cluster-templates/issues/7)

## Summary

When external projects use the standard template, they need to customize service names, compose project names, and devcontainer names to avoid collisions with other projects on the same Docker host. Currently these are hardcoded (e.g., service name `orchestrator`, devcontainer name `Generacy Development Cluster`).

Additionally, environment configuration should be split into checked-in project defaults and gitignored user secrets.

## Problem

- Docker container names collide when running multiple projects from the same template
- VS Code window titles are all identical ("Generacy Development Cluster")
- No way to distinguish which containers belong to which project in Docker Desktop
- Secrets (GH_TOKEN, CLAUDE_API_KEY) have no clear separation from project config (REPO_URL, WORKER_COUNT)

## Proposed Solution

### 1. Template Placeholders

Add placeholders in template files that are replaced during project initialization:

**docker-compose.yml:**
- Add `name: {{PROJECT_NAME}}` at top level
- Rename `orchestrator` service to `{{PROJECT_NAME}}` (or a configurable service name)

**devcontainer.json:**
- `"name": "{{PROJECT_NAME}}"` 
- `"service": "{{PROJECT_NAME}}"`
- `"runServices": ["{{PROJECT_NAME}}", "redis"]`
- `"workspaceFolder": "/workspaces/{{REPO_NAME}}"`

### 2. `.env` Split

Replace the single `.env` file approach with:

```yaml
env_file:
  - path: .env           # Project defaults, checked into source control
  - path: .env.local     # User secrets, gitignored
    required: false
```

**`.env` (checked in):**
```env
PROJECT_NAME=my-project
REPO_URL=https://github.com/org/my-project.git
REPO_BRANCH=main
WORKER_COUNT=3
ORCHESTRATOR_PORT=3100
```

**`.env.local` (gitignored) — template provided as `.env.local.template`:**
```env
GH_TOKEN=
GH_USERNAME=
GH_EMAIL=
CLAUDE_API_KEY=
```

### 3. Initialization Script

Add an `init-template.sh` (or integrate into generacy CLI) that:
- Prompts for or accepts `PROJECT_NAME` and `REPO_URL`
- Performs `sed` replacement of `{{PLACEHOLDER}}` values
- Creates `.env` with project defaults
- Adds `.env.local` to `.gitignore`
- Copies `.env.local.template` for reference

## Files Affected

- `.devcontainer/docker-compose.yml` — add `name:`, rename service, update `env_file`
- `.devcontainer/devcontainer.json` — parameterize name, service, workspaceFolder
- `.devcontainer/.env.template` → split into `.env` + `.env.local.template`
- `.gitignore` — add `.env.local`
- New: `init-template.sh` or equivalent

## Context

Discovered while onboarding an external project (`markdown-preview-tool`). The user had to manually rename `orchestrator` → `generacy` and add `name: markdown-preview-tool` to the compose file to distinguish containers.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## User Stories

### US1: External Developer Onboarding

**As an** external developer adopting the cluster template,
**I want** to set a project name that customizes container names, compose project name, and VS Code window title,
**So that** my containers don't collide with other projects on the same Docker host.

**Acceptance Criteria**:
- [ ] Running `init-template.sh` with a project name replaces all `{{PROJECT_NAME}}` placeholders
- [ ] Docker containers are named with the project-specific prefix
- [ ] VS Code window title reflects the project name
- [ ] `docker compose ps` shows distinguishable service names per project

### US2: Secret Separation

**As a** developer working on a team,
**I want** project configuration separated from personal secrets,
**So that** I can commit project defaults (repo URL, worker count) without exposing tokens.

**Acceptance Criteria**:
- [ ] `.env` contains only project configuration and is checked into source control
- [ ] `.env.local` holds secrets (GH_TOKEN, CLAUDE_API_KEY) and is gitignored
- [ ] `.env.local.template` documents required secret variables
- [ ] Containers start successfully with both env files loaded

### US3: Multi-Project Coexistence

**As a** developer running multiple cluster-template projects simultaneously,
**I want** each project's containers to have unique names and network isolation,
**So that** I can run them side-by-side without conflicts.

**Acceptance Criteria**:
- [ ] Two projects initialized with different names can run concurrently
- [ ] Docker Desktop shows distinct container groups per project
- [ ] No port or network name collisions between projects

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Add `{{PROJECT_NAME}}` placeholders to docker-compose.yml and devcontainer.json | P1 | Both standard and microservices variants |
| FR-002 | Add `name:` top-level key to docker-compose.yml using `{{PROJECT_NAME}}` | P1 | Sets compose project name |
| FR-003 | Rename `orchestrator` service to use `{{PROJECT_NAME}}` placeholder | P1 | Affects service name, container name |
| FR-004 | Split `.env.template` into `.env` (project config) and `.env.local.template` (secrets) | P1 | |
| FR-005 | Update `env_file:` in docker-compose.yml to load both `.env` and `.env.local` | P1 | `.env.local` should be `required: false` |
| FR-006 | Create `init-template.sh` script for placeholder replacement | P1 | Accepts PROJECT_NAME, REPO_URL as args or prompts |
| FR-007 | Add `.env.local` to `.gitignore` in both variants | P1 | |
| FR-008 | Add `{{REPO_NAME}}` placeholder to `workspaceFolder` in devcontainer.json | P2 | Derived from REPO_URL or separately specified |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | Template initialization | Completes in < 5 seconds | Run `init-template.sh` and verify all placeholders replaced |
| SC-002 | No hardcoded project names | 0 remaining `Generacy Development Cluster` or hardcoded `orchestrator` references | `grep` for hardcoded values after init |
| SC-003 | Secrets not in VCS | `.env.local` never committed | Verify `.gitignore` contains `.env.local` |
| SC-004 | Both variants supported | Standard and microservices templates both work | Build Dockerfiles for both variants after initialization |

## Assumptions

- Both `standard/` and `microservices/` variants will receive the same placeholder treatment
- The `init-template.sh` script is a bash script (no additional runtime dependencies)
- The `{{PLACEHOLDER}}` syntax won't conflict with existing file content (e.g., Docker Compose variable interpolation uses `${VAR}`)
- Users have `sed` available (standard on Linux/macOS, available in Git Bash on Windows)

## Out of Scope

- Integration with the Generacy CLI (future enhancement)
- Automatic port assignment to avoid port collisions between projects
- Template versioning or update mechanism
- Windows-native (non-WSL) support for `init-template.sh`

---

*Generated by speckit*
