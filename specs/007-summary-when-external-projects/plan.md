# Implementation Plan: Template Placeholders and .env Split

**Feature**: Add template placeholders and .env split for project-specific configuration
**Branch**: `007-summary-when-external-projects`
**Status**: Complete

## Summary

Transform the cluster template files into parameterized templates with `{{PLACEHOLDER}}` markers, split environment configuration into project defaults (`.env`, checked in) and user secrets (`.env.local`, gitignored), and provide an `init-template.sh` script that initializes a template for a specific project.

Both `standard/` and `microservices/` variants receive identical treatment.

## Technical Context

- **Language**: Bash (init script), YAML (docker-compose), JSON (devcontainer)
- **Dependencies**: `sed`, `basename` (standard POSIX tools)
- **Docker Compose**: v2 format with top-level `name:` support
- **Placeholder syntax**: `{{VARIABLE}}` — chosen to avoid conflict with Docker Compose's `${VAR}` interpolation

## Design Decisions

### D1: Service Names — Keep Semantic Names (Option A from Q1)

Keep service names as `orchestrator`, `worker`, `redis`. Add only the top-level `name: {{PROJECT_NAME}}` to docker-compose.yml. Docker Compose automatically prefixes container names (e.g., `myproject-orchestrator-1`), which provides sufficient disambiguation without losing semantic meaning or requiring cascading reference updates.

### D2: Port Collisions — Document, Don't Automate (Option C from Q2)

Remove the "no port collisions" acceptance criterion from US3 since automatic port assignment is explicitly out of scope. Document in quickstart.md that users running multiple projects must manually adjust `ORCHESTRATOR_PORT` in `.env`. The `ORCHESTRATOR_PORT` variable already exists in `.env.template`.

### D3: Init Script Location — Repo Root, Operates In-Place (Option C from Q3)

Place `init-template.sh` at repo root. It targets a specified variant directory (default: `standard`) and performs in-place replacement. This fits the expected workflow: user clones/forks the template repo, runs init, then has a ready-to-use devcontainer.

### D4: Volume Name Isolation — Rely on Auto-Prefixing (Option A from Q4)

Docker Compose's top-level `name:` automatically prefixes volume names. No explicit volume `name:` overrides needed — simpler and follows standard Compose behavior.

### D5: REPO_NAME Derivation — Auto-Derive with Override (Option A from Q5)

Auto-derive `REPO_NAME` from `REPO_URL` by stripping the path and removing `.git` suffix. Allow override via `--repo-name` flag.

## Project Structure

```
cluster-templates/
├── init-template.sh                          # NEW — initialization script
├── .gitignore                                # NEW — repo-level gitignore
├── standard/.devcontainer/
│   ├── docker-compose.yml                    # MODIFY — add name:, update env_file
│   ├── devcontainer.json                     # MODIFY — parameterize name, workspaceFolder
│   ├── .env.template                         # MODIFY → becomes .env (project defaults only)
│   └── .env.local.template                   # NEW — secret variable template
├── microservices/.devcontainer/
│   ├── docker-compose.yml                    # MODIFY — add name:, update env_file
│   ├── devcontainer.json                     # MODIFY — parameterize name, workspaceFolder
│   ├── .env.template                         # MODIFY → becomes .env (project defaults only)
│   └── .env.local.template                   # NEW — secret variable template
└── specs/...
```

## Implementation Phases

### Phase 1: Template Placeholders in docker-compose.yml

**Both variants:**

1. Add top-level `name: {{PROJECT_NAME}}` to docker-compose.yml
2. Update `env_file:` section from single `.env` to dual-file loading:
   ```yaml
   env_file:
     - path: .env
     - path: .env.local
       required: false
   ```
3. Keep service names (`orchestrator`, `worker`, `redis`) unchanged

**Standard-specific:** No additional changes beyond the above.

**Microservices-specific:** Same changes applied to the microservices docker-compose.yml.

### Phase 2: Template Placeholders in devcontainer.json

**Both variants:**

1. Change `"name"` from `"Generacy Development Cluster"` to `"{{PROJECT_NAME}}"`
2. Change `"workspaceFolder"` from `"/workspaces"` to `"/workspaces/{{REPO_NAME}}"`
3. Keep `"service": "orchestrator"` unchanged (service names stay semantic)

### Phase 3: .env File Split

**For each variant:**

1. Rename `.env.template` to `.env` containing only project configuration:
   ```env
   PROJECT_NAME={{PROJECT_NAME}}
   REPO_URL={{REPO_URL}}
   REPO_BRANCH=main
   WORKER_COUNT=3
   ORCHESTRATOR_PORT=3100
   ```

2. Create `.env.local.template` containing secret variables:
   ```env
   # User secrets — copy to .env.local and fill in values
   # This file is gitignored and should NOT be committed
   GH_TOKEN=
   GH_USERNAME=
   GH_EMAIL=
   CLAUDE_API_KEY=
   ```

3. Preserve optional config variables (MONITORED_REPOS, LABEL_MONITOR_ENABLED, etc.) in `.env` with sensible defaults.

### Phase 4: Initialization Script

Create `init-template.sh` at repo root:

```bash
#!/usr/bin/env bash
# Usage: ./init-template.sh --name <project-name> --repo <repo-url> [--variant standard|microservices] [--repo-name <name>]
```

**Features:**
- Accepts `--name`, `--repo`, `--variant` (default: standard), `--repo-name` (optional)
- Auto-derives REPO_NAME from REPO_URL if not specified
- Replaces `{{PROJECT_NAME}}` and `{{REPO_NAME}}` in all files under the target variant
- Populates `.env` with actual values (replaces placeholder tokens)
- Copies `.env.local.template` as reference
- Validates inputs (non-empty project name, valid URL format)
- Prints summary of changes made
- Interactive mode: prompts for values if not provided via flags

**Implementation notes:**
- Use `sed -i` for in-place replacement
- Target files: `docker-compose.yml`, `devcontainer.json`, `.env`
- Skip binary files and the script itself
- Use portable sed syntax (compatible with GNU sed)

### Phase 5: .gitignore

Create `.gitignore` at repo root:
```
.env.local
```

### Phase 6: Validation & Documentation

- Verify both variants build successfully after placeholder insertion
- Update quickstart.md with initialization workflow
- Document multi-project port configuration

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `init-template.sh` | Create | Template initialization script |
| `.gitignore` | Create | Gitignore for .env.local |
| `standard/.devcontainer/docker-compose.yml` | Modify | Add `name:`, update `env_file:` |
| `standard/.devcontainer/devcontainer.json` | Modify | Parameterize name, workspaceFolder |
| `standard/.devcontainer/.env.template` | Rename/Modify | Becomes `.env` with project config only |
| `standard/.devcontainer/.env.local.template` | Create | Secret variables template |
| `microservices/.devcontainer/docker-compose.yml` | Modify | Add `name:`, update `env_file:` |
| `microservices/.devcontainer/devcontainer.json` | Modify | Parameterize name, workspaceFolder |
| `microservices/.devcontainer/.env.template` | Rename/Modify | Becomes `.env` with project config only |
| `microservices/.devcontainer/.env.local.template` | Create | Secret variables template |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| `sed` behavior differs between GNU/BSD | Init script fails on macOS | Use portable sed patterns; test on both |
| Placeholders accidentally replaced in wrong files | Broken config | Target only specific files by path |
| Existing users have `.env` based on old `.env.template` | Migration confusion | Document migration path in quickstart.md |
| `{{PLACEHOLDER}}` syntax in YAML could cause parse issues | docker-compose fails to parse | Verify YAML validity with placeholders present |

## Testing Strategy

1. **Unit**: Run `init-template.sh` with test values, verify all placeholders replaced
2. **Build**: `docker build` both variants after initialization
3. **Integration**: `docker compose up` with initialized config, verify containers start
4. **Multi-project**: Initialize two copies with different names, verify no collisions
