# Feature Specification: Port Shared Volume Package Install Approach with Release Channels

Adopt the shared volume + wrapper script pattern validated in tetrad-development, but install packages from npm (instead of building from source) with configurable release channels for external developers.

**Branch**: `012-summary-adopt-shared-volume` | **Date**: 2026-03-08 | **Status**: Draft

## Summary

Port the shared volume pattern from tetrad-development to cluster-templates. Instead of baking generacy/agency packages into Docker images, the orchestrator installs them from npm into a shared volume at startup. Workers mount the volume read-only and use wrapper scripts to access the CLIs. This allows developers to stay on the latest package version without rebuilding images, and supports configurable release channels (`stable`/`preview`).

## Background

tetrad-development has validated a pattern where the orchestrator populates a shared volume with built packages that workers mount. This issue ports that pattern to cluster-templates with npm-based installation instead of source builds.

Currently, Docker images bake in generacy/agency packages. Instead, packages should be installed at container startup from npm, allowing developers to stay on the latest version without rebuilding images.

## Implementation Notes (from tetrad-development validation)

### Wrapper scripts, not `npm link`
Workers must **not** use `npm link` to install CLIs — concurrent `npm link` from multiple workers causes EROFS errors on the shared overlayfs layer. Instead, create thin wrapper scripts in `~/.local/bin/`:
```sh
#!/bin/sh
exec node /path/to/shared-volume/package/bin/cli.js "$@"
```
See tetrad-development PR #39 for the validated pattern.

### Speckit command files ship in the npm package
`@generacy-ai/agency-plugin-spec-kit` already includes command `.md` files in its `commands/` directory. `generacy setup build` Phase 4 resolves and copies them to `~/.claude/commands/`. No need to clone the agency repo — the npm package at `{npm root -g}/@generacy-ai/agency-plugin-spec-kit/commands` is sufficient.

### Slash commands use plain names
Phase commands are `/specify`, `/clarify`, `/plan`, `/tasks`, `/implement` — not namespaced. Ensure cluster-templates pulls generacy/orchestrator versions that include this fix (generacy PR #353).

### `setup-speckit.sh` recovery should use npm, not git clone
The current `setup-speckit.sh` clones the entire agency repo as a fallback. Replace with `npm install -g @generacy-ai/agency-plugin-spec-kit` followed by re-running `generacy setup build`.

### PATH persistence
`~/.local/bin` must be added to PATH both via `export` in the entrypoint (for the current process) and appended to `~/.bashrc` (for Claude Code subprocesses that spawn new shells during implement phases).

## Dependencies

- ✅ `generacy-ai/agency` — speckit command files already bundled in agency-plugin-spec-kit npm package
- ✅ `generacy-ai/generacy` — slash command namespace fix merged (PR #353), speckit resolution fix merged (PR #352)
- ✅ `generacy-ai/tetrad-development` — shared volume approach validated (PR #39), EROFS race condition fixed
- ⬜ Packages need to be **published to npm** before cluster-templates can consume them

## Notes

- This issue should be implemented **after** the npm packages are published with the latest fixes
- Both `standard` and `microservices` template variants need identical changes

## User Stories

### US1: External developer onboarding without image rebuilds

**As an** external developer using a cluster-templates devcontainer,
**I want** generacy/agency packages installed from npm at container startup,
**So that** I can stay on the latest stable release without rebuilding Docker images.

**Acceptance Criteria**:
- [ ] Container starts up and installs packages from npm into shared volume
- [ ] Workers can invoke `generacy` and `agency` CLIs without errors
- [ ] No Docker image rebuild required to pick up a new package version

### US2: Release channel selection

**As a** developer who wants to test preview features,
**I want** to set `GENERACY_CHANNEL=preview` in my environment,
**So that** the orchestrator installs preview-channel packages instead of stable ones.

**Acceptance Criteria**:
- [ ] `GENERACY_CHANNEL=stable` (default) installs stable npm tags
- [ ] `GENERACY_CHANNEL=preview` installs preview npm tags
- [ ] Switching channels takes effect on next container restart without image rebuild

### US3: Fast startup via skip and version checks

**As a** developer iterating quickly or working offline,
**I want** options to skip or short-circuit npm install,
**So that** container startup is fast when packages are already up to date.

**Acceptance Criteria**:
- [ ] `SKIP_PACKAGE_UPDATE=true` skips npm install entirely
- [ ] Install is skipped automatically when installed version matches the requested version
- [ ] npm cache volume persists across restarts for fast installs when updates are needed

### US4: Speckit recovery without cloning agency repo

**As a** developer whose speckit setup failed,
**I want** `setup-speckit.sh` to recover using `npm install`,
**So that** the recovery path doesn't require cloning the entire agency repository.

**Acceptance Criteria**:
- [ ] `setup-speckit.sh` runs `npm install -g @generacy-ai/agency-plugin-spec-kit` as recovery
- [ ] Re-runs `generacy setup build` after npm install
- [ ] Does not clone the agency git repo

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Remove baked-in generacy/agency packages from Dockerfiles | P1 | Slims images |
| FR-002 | Add named shared volume for packages in docker-compose.yml (both variants) | P1 | Orchestrator writes, workers read |
| FR-003 | Add named npm cache volume in docker-compose.yml (both variants) | P2 | Speeds up repeated installs |
| FR-004 | Orchestrator entrypoint: install packages from npm to shared volume at startup | P1 | Respects `GENERACY_CHANNEL` |
| FR-005 | Orchestrator entrypoint: skip install if version already matches | P2 | Avoids unnecessary npm calls |
| FR-006 | Orchestrator entrypoint: skip install if `SKIP_PACKAGE_UPDATE=true` | P2 | Offline / fast-iteration use |
| FR-007 | Worker entrypoint: mount shared volume read-only | P1 | Workers do not write |
| FR-008 | Worker entrypoint: create wrapper scripts in `~/.local/bin/` for each CLI | P1 | No `npm link` |
| FR-009 | Worker entrypoint: add `~/.local/bin` to PATH via export and `~/.bashrc` | P1 | Required for subprocesses |
| FR-010 | `setup-speckit.sh`: replace git clone fallback with `npm install -g` | P1 | Simpler, correct recovery |
| FR-011 | Apply changes to both `standard` and `microservices` variants | P1 | Parity requirement |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | Container startup installs correct packages | 100% of starts | Observe logs; CLIs respond to `--version` |
| SC-002 | Workers can invoke `generacy` and `agency` CLIs | No errors | Run CLIs inside worker container |
| SC-003 | Version-match skip works | Install skipped on second restart | Observe logs showing skip message |
| SC-004 | `SKIP_PACKAGE_UPDATE=true` skips install | Install skipped | Observe logs |
| SC-005 | `GENERACY_CHANNEL=preview` installs preview packages | Preview version installed | Check `generacy --version` output |
| SC-006 | `setup-speckit.sh` recovery uses npm, not git | No git clone in recovery path | Code review + manual test |
| SC-007 | Docker images build successfully after changes | Clean `docker build` | CI / manual build |

## Assumptions

- npm packages `@generacy-ai/generacy` and `@generacy-ai/agency-plugin-spec-kit` will be published before implementation begins
- The `stable` and `preview` npm dist-tags are maintained on the published packages
- Worker containers have read access to the shared volume at the same mount path as the orchestrator writes to

## Out of Scope

- Publishing npm packages (tracked separately; must be done before this issue)
- Changes to the generacy or agency source packages themselves
- Windows or non-Linux host support changes

---

*Generated by speckit*
