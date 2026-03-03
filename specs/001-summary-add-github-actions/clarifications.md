# Clarification Questions

## Status: Pending

## Questions

### Q1: PR Trigger Scope
**Context**: FR-003 states "trigger on all pull requests" but doesn't specify target branch filtering. Triggering on literally all PRs (including those targeting feature branches) may cause unnecessary CI runs, while filtering to only PRs targeting `main`/`develop` is the more common pattern and aligns with the push trigger scope in FR-002.
**Question**: Should the workflow trigger on all pull requests regardless of target branch, or only on PRs targeting `main` and `develop`?
**Options**:
- A) All PRs: Trigger on every pull request regardless of target branch. Maximum coverage but more CI usage.
- B) PRs targeting main/develop only: Only trigger when the PR targets `main` or `develop`. Matches push trigger scope and reduces unnecessary runs.
**Answer**:

### Q2: Path Filtering
**Context**: The workflow triggers are defined by branch/PR events, but the spec doesn't address whether CI should run when unrelated files change (e.g., README edits, spec documents, CLAUDE.md). Path filtering (`paths:`) can skip CI for changes that can't affect Dockerfile or compose validity, saving runner minutes.
**Question**: Should the workflow use path filtering to only run when relevant files change (e.g., `standard/**`, `microservices/**`, `.github/workflows/**`), or run on every push/PR regardless of which files changed?
**Options**:
- A) No path filtering: Run CI on every qualifying push/PR regardless of changed files. Simpler configuration, guaranteed coverage.
- B) Path filtering: Only run when files in `standard/`, `microservices/`, or `.github/workflows/` change. Saves CI minutes but could miss edge cases if new paths are added later.
**Answer**:

### Q3: Matrix Fail-Fast Behavior
**Context**: GitHub Actions matrix strategy defaults to `fail-fast: true`, meaning if the `standard` variant fails, the `microservices` job is cancelled (and vice versa). US3 emphasizes clear feedback on which variant failed, which suggests both should always run to completion so contributors see the full picture.
**Question**: Should the matrix use fail-fast (cancel other variants when one fails) or always run all variants to completion?
**Options**:
- A) Fail-fast enabled (default): Cancel remaining matrix jobs when one fails. Faster feedback and fewer wasted runner minutes.
- B) Fail-fast disabled: Always run all variants to completion. Contributors see the full status of every variant even when one fails.
**Answer**:

### Q4: Concurrency Control
**Context**: When a contributor pushes multiple commits in quick succession to the same branch, multiple workflow runs queue up. Concurrency groups can automatically cancel in-progress runs, saving runner minutes and avoiding stale results. This is a common CI optimization not mentioned in the spec.
**Question**: Should the workflow use concurrency groups to cancel in-progress runs when new commits are pushed to the same branch/PR?
**Options**:
- A) No concurrency control: Let all triggered runs complete. Simpler, but may waste runner minutes on superseded commits.
- B) Cancel in-progress runs: Use concurrency groups to cancel stale runs when a new push arrives for the same branch/PR. Saves resources and shows only the latest result.
**Answer**:

### Q5: devcontainer.json Validation
**Context**: The spec covers Dockerfile builds (FR-004/FR-005) and Docker Compose config validation (FR-006/FR-007), but both variants also include `devcontainer.json` files that define VS Code/devcontainer settings. These JSON files could have syntax errors or invalid schema that wouldn't be caught by the current checks.
**Question**: Should the workflow also validate `devcontainer.json` files (e.g., JSON syntax check or schema validation), or is Dockerfile + Compose validation sufficient?
**Options**:
- A) Skip devcontainer.json validation: Only validate Dockerfiles and Compose files as specified. Keep scope minimal.
- B) Add JSON syntax check: Validate that `devcontainer.json` files are valid JSON (lightweight, catches syntax errors).
- C) Add schema validation: Validate `devcontainer.json` against the devcontainer schema using `devcontainer` CLI or a JSON schema validator. More thorough but adds a tool dependency.
**Answer**:

### Q6: Compose Bind Mount Host Files
**Context**: Both `docker-compose.yml` files bind-mount `${HOME}/.claude.json:/home/node/.claude.json:ro`. While `docker compose config` validates YAML structure and variable substitution (not file existence), the behavior around missing bind mount source files could vary across Docker Compose versions. Creating a dummy file in CI would make validation more robust.
**Question**: Should the workflow create dummy/empty files for bind-mounted host paths (like `~/.claude.json`) before running `docker compose config`, or rely on the current behavior where config validation ignores file existence?
**Options**:
- A) No dummy files: Trust that `docker compose config` only validates structure. Simpler, but could break if compose behavior changes.
- B) Create dummy files: Create empty placeholder files for known bind mount sources before validation. Defensive approach that guards against compose version differences.
**Answer**:
