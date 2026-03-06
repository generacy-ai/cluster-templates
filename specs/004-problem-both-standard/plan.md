# Implementation Plan: Ensure speckit commands and Agency MCP are installed during onboarding

**Feature**: Fix silent setup failures that leave new projects without speckit commands and Agency MCP
**Branch**: `004-problem-both-standard`
**Status**: Complete

## Summary

All four entrypoint scripts (`standard` and `microservices` variants, worker and orchestrator) suppress errors from `generacy setup` commands via `2>/dev/null || true`. When `generacy setup build` Phase 4 fails (because the agency repo isn't cloned), speckit commands and the Agency MCP server are never installed, leaving workers non-functional with no error feedback.

The fix:
1. Add a post-setup step that ensures agency repo is present and `generacy setup build` Phase 4 succeeds
2. Replace blanket error suppression with proper error logging
3. Add a pre-flight check in worker entrypoints to verify speckit readiness before accepting tasks

## Technical Context

- **Language**: Bash (shell scripts)
- **Platform**: Docker containers (Debian Bookworm base)
- **Dependencies**: `generacy` CLI (`@generacy-ai/generacy@preview`), `agency` MCP server (`@generacy-ai/agency@preview`), Claude Code
- **Container runtime**: Docker Compose with `set -e` in all entrypoints
- **Existing patterns**: Structured logging via `log()` function, conditional tool execution via `command -v`

## Design Decisions (Unanswered Clarifications)

Since clarifications Q1-Q5 are unanswered, the plan uses these reasonable defaults:

| Question | Default Decision | Rationale |
|----------|-----------------|-----------|
| Q1: Agency clone mechanism | **Option C**: Check if `/workspaces/agency` exists after setup, clone manually if missing | Least invasive; doesn't assume CLI flags exist |
| Q2: Error handling strategy | **Option C**: Selective — fail hard on `setup build`, log-and-continue on `setup auth` | Auth failures shouldn't block startup; build failures should |
| Q3: Pre-flight checks | **Option C**: Both slash commands and MCP server config | Most thorough; matches US3 acceptance criteria |
| Q4: Pre-flight failure | **Option A**: Exit with error — worker refuses to start | Matches "fail fast" requirement in US3 |
| Q5: Orchestrator scope | **Option C**: Workers get full check, orchestrator gets lighter version | Orchestrator doesn't directly execute speckit phases |

## Project Structure

```
standard/.devcontainer/scripts/
├── entrypoint-orchestrator.sh   # Modified: error logging, light speckit check
├── entrypoint-worker.sh         # Modified: error logging, full pre-flight check
├── setup-credentials.sh         # Unchanged
└── setup-speckit.sh             # NEW: shared speckit setup + verification

microservices/.devcontainer/scripts/
├── entrypoint-orchestrator.sh   # Modified: error logging, light speckit check
├── entrypoint-worker.sh         # Modified: error logging, full pre-flight check
├── setup-credentials.sh         # Unchanged
├── setup-docker-dind.sh         # Unchanged
└── setup-speckit.sh             # NEW: shared speckit setup + verification
```

## Implementation Approach

### 1. Create shared `setup-speckit.sh` script

A new script placed in both `standard/.devcontainer/scripts/` and `microservices/.devcontainer/scripts/` that:

- Checks if `/workspaces/agency` exists after `generacy setup workspace`
- If missing, clones it via `git clone https://github.com/generacy-ai/agency /workspaces/agency`
- Runs `npm install` and `npm run build` in the agency directory if needed
- Re-runs `generacy setup build` to trigger Phase 4
- Provides a `verify_speckit()` function that checks:
  - Slash command files exist in `~/.claude/commands/` (e.g., `specify.md`)
  - Agency MCP server entry exists in Claude settings

### 2. Update error handling in all 4 entrypoints

Replace the current pattern:
```bash
generacy setup auth 2>/dev/null || true
generacy setup workspace --clean 2>/dev/null || true
generacy setup build 2>/dev/null || true
```

With a selective error handling pattern:
```bash
SETUP_LOG="/tmp/generacy-setup.log"

# Non-critical: log errors but continue
generacy setup auth 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup auth' failed (see $SETUP_LOG)"

# Critical: log errors but continue (workspace needed for build)
generacy setup workspace --clean 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup workspace' failed (see $SETUP_LOG)"

# Critical: fail on error (speckit depends on this)
generacy setup build 2>>"$SETUP_LOG" || {
    log "ERROR: 'generacy setup build' failed (see $SETUP_LOG)"
    # Attempt speckit recovery
    bash /usr/local/bin/setup-speckit.sh 2>>"$SETUP_LOG"
}
```

### 3. Add pre-flight check to worker entrypoints

After setup completes, before `exec generacy orchestrator --worker-only`:
```bash
# Pre-flight: verify speckit readiness
if ! bash /usr/local/bin/setup-speckit.sh --verify; then
    log "FATAL: Speckit commands not available. Worker cannot process phases."
    log "FATAL: Check $SETUP_LOG for setup errors."
    log "FATAL: Ensure agency repo is accessible and 'generacy setup build' succeeds."
    exit 1
fi
```

### 4. Add light check to orchestrator entrypoints

After setup, before `exec generacy orchestrator`:
```bash
# Light check: warn if speckit is missing (orchestrator can still run)
if ! bash /usr/local/bin/setup-speckit.sh --verify 2>/dev/null; then
    log "WARNING: Speckit commands not available. Workers may fail to process phases."
fi
```

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `standard/.devcontainer/scripts/setup-speckit.sh` | **New** | Shared speckit setup and verification script |
| `microservices/.devcontainer/scripts/setup-speckit.sh` | **New** | Identical copy for microservices variant |
| `standard/.devcontainer/scripts/entrypoint-worker.sh` | **Modified** | Error logging + pre-flight check (fail-fast) |
| `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` | **Modified** | Error logging + light speckit warning |
| `microservices/.devcontainer/scripts/entrypoint-worker.sh` | **Modified** | Error logging + pre-flight check (fail-fast) |
| `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` | **Modified** | Error logging + light speckit warning |

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Agency repo URL changes | Use environment variable `AGENCY_REPO_URL` with default fallback |
| Network issues during clone | Retry with backoff (max 3 attempts) before failing |
| `set -e` kills container on first error | Use subshell or explicit `|| { handle; }` pattern for recoverable errors |
| Duplicate setup-speckit.sh in both variants | Accept duplication for now; both variants have separate script directories |

## Testing Strategy

1. **Build validation**: `docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/` for both variants
2. **Scenario: Fresh onboarding** — Start containers without agency repo pre-cloned, verify speckit commands are available after startup
3. **Scenario: Setup failure** — Block network access to agency repo, verify error messages are logged and worker fails to start
4. **Scenario: Existing setup** — Start with agency already cloned, verify no duplicate work or errors
