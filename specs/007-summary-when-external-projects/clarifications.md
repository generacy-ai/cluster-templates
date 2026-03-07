# Clarifications

Questions and answers to clarify the feature specification.

## Batch 1 - 2026-03-07 16:12

### Q1: Service Rename vs Project Name
**Context**: FR-003 says rename the `orchestrator` service to `{{PROJECT_NAME}}`. However, adding `name: {{PROJECT_NAME}}` (FR-002) already causes Docker Compose to prefix all container names (e.g., `myproject-orchestrator-1`). Renaming the service itself from `orchestrator` to `{{PROJECT_NAME}}` would lose the semantic meaning (it IS an orchestrator) and also require updating `worker.depends_on`, `devcontainer.json.service`, and `runServices`. The original issue context shows the user renamed `orchestrator` → `generacy` (a project name), but `name:` achieves the same disambiguation more cleanly.
**Question**: Should the `orchestrator` service be renamed to `{{PROJECT_NAME}}`, or is adding the top-level `name: {{PROJECT_NAME}}` sufficient for container disambiguation (keeping service names as `orchestrator`, `worker`, `redis`)?
**Options**:
- A: Keep service names (`orchestrator`, `worker`, `redis`) and only add `name: {{PROJECT_NAME}}` — containers become `myproject-orchestrator-1`
- B: Rename `orchestrator` service to `{{PROJECT_NAME}}` as spec says — requires updating depends_on, devcontainer.json references
- C: Rename to `{{PROJECT_NAME}}-orchestrator` — preserves role while adding project prefix at service level

**Answer**: *Pending*

### Q2: Port Collision Contradiction
**Context**: US3 acceptance criteria states 'No port or network name collisions between projects', but the Out of Scope section explicitly says 'Automatic port assignment to avoid port collisions between projects'. The standard template forwards ports 3100 and 6379 in devcontainer.json, which WILL collide if two projects run simultaneously. These are contradictory requirements.
**Question**: Should US3's 'no port collisions' acceptance criterion be removed (since port assignment is out of scope), or should we add `ORCHESTRATOR_PORT` as a placeholder so users can set different ports per project?
**Options**:
- A: Remove the port collision AC from US3 — it's out of scope as stated
- B: Make ORCHESTRATOR_PORT a project-level config in .env (already used as env var), and parameterize forwardPorts in devcontainer.json
- C: Document that users must manually change ports for multi-project setups, but don't automate it

**Answer**: *Pending*

### Q3: Init Script Location and Scope
**Context**: The spec mentions `init-template.sh` but doesn't specify where it lives or whether it handles one or both variants. The repo has `standard/` and `microservices/` as separate directories. A user typically copies one variant into their project — so the script could be at the repo root (runs before copying), inside each variant (runs after copying), or a single script that targets a chosen variant.
**Question**: Where should `init-template.sh` live and what is its expected workflow — does the user run it inside a copied variant directory, or does it copy+initialize a variant into a new project?
**Options**:
- A: Place inside each variant's `.devcontainer/` — user copies a variant then runs the script in-place
- B: Place at repo root — user runs `./init-template.sh --variant standard --name myproject` which copies and initializes
- C: Place at repo root but operates on the variant in-place (no copy) — for users who clone/fork the template repo

**Answer**: *Pending*

### Q4: Volume Name Isolation
**Context**: Both variants use named volumes (`workspace`, `claude-config`, `redis-data`). Setting the top-level `name:` in docker-compose.yml causes Docker Compose to auto-prefix volume names with the project name (e.g., `myproject_workspace`). However, the current volumes section doesn't use explicit `name:` overrides, so the auto-prefixing behavior depends on the compose version and whether `name:` is set.
**Question**: Is relying on Docker Compose's automatic volume name prefixing (via the top-level `name:`) sufficient, or should volumes also get explicit `name: {{PROJECT_NAME}}-workspace` etc.?
**Options**:
- A: Rely on automatic prefixing via top-level `name:` — simpler, standard Docker Compose behavior
- B: Add explicit `name:` to each volume for guaranteed isolation — more verbose but explicit

**Answer**: *Pending*

### Q5: REPO_NAME Derivation
**Context**: FR-008 says `{{REPO_NAME}}` should be used in devcontainer.json's `workspaceFolder` and can be 'derived from REPO_URL or separately specified'. If derived, `https://github.com/org/my-project.git` → `my-project`. But the init script needs to know whether to prompt for it separately or extract it automatically. Currently `workspaceFolder` is just `/workspaces` (no repo name).
**Question**: Should `REPO_NAME` be automatically derived from `REPO_URL` in the init script (with option to override), or should it be a separate required input?
**Options**:
- A: Auto-derive from REPO_URL (strip path, remove .git suffix), allow override with --repo-name flag
- B: Require as separate input alongside PROJECT_NAME and REPO_URL
- C: Default to PROJECT_NAME (assume repo name matches project name), allow override

**Answer**: *Pending*

