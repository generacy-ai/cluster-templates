# Clarifications

Questions and answers to clarify the feature specification.

## Batch 1 - 2026-03-07 16:27

### Q1: Microservices variant scope
**Context**: The spec lists microservices entrypoint scripts as affected files with '(if applicable)'. This ambiguity affects implementation scope — applying changes to microservices doubles the file count and testing surface.
**Question**: Should the same changes (derived clone path, devcontainer detection, --config flag) be applied to the microservices variant entrypoint scripts, or is this feature scoped to standard only?
**Options**:
- A: Apply to both standard and microservices variants
- B: Standard only — microservices will be handled separately

**Answer**: *Pending*

### Q2: Multiple repos in /workspaces
**Context**: The devcontainer detection uses `find /workspaces -maxdepth 2 -name .git` to locate an existing repo. In a multi-repo workspace (e.g., after generacy setup workspace clones additional repos), this could match the wrong repo.
**Question**: When multiple .git directories exist under /workspaces in devcontainer mode, how should the entrypoint determine which is the primary repo? Should it use the REPO_URL basename to match, or is `head -1` (first found) sufficient?
**Options**:
- A: Match by REPO_URL basename — look for /workspaces/<derived-name>/.git specifically
- B: Use first found (head -1) — in practice there's only one repo at entrypoint time

**Answer**: *Pending*

### Q3: Backwards compatibility for /workspaces/project
**Context**: Existing users may have scripts, CI configs, or documentation referencing `/workspaces/project`. Changing the clone path could break these references silently.
**Question**: Are there any known references to `/workspaces/project` in CI pipelines, user scripts, or documentation outside this repo that need updating, or can we assume no external dependencies on that path?
**Options**:
- A: No external dependencies — safe to change the path
- B: There are external references that need a migration path (e.g., symlink from /workspaces/project)

**Answer**: *Pending*

