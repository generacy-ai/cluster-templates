# Feature Specification: Ensure speckit commands and Agency MCP are installed during onboarding

**Branch**: `004-problem-both-standard` | **Date**: 2026-03-06 | **Status**: Draft
**Issue**: [#4](https://github.com/generacy-ai/cluster-templates/issues/4)

## Summary

Both `standard` and `microservices` template entrypoints silently fail to install speckit commands and the Agency MCP server during onboarding. This leaves new projects with non-functional worker pipelines and zero error feedback. The fix ensures the `agency` repo is available, errors are surfaced, and a pre-flight check verifies speckit readiness before workers start.

## Problem

Both template entrypoints run:
```bash
generacy setup build 2>/dev/null || true
```

Phase 4 of `generacy setup build` (added in generacy#309) installs speckit slash commands and configures the Agency MCP server. However, this phase depends on the agency repo being cloned to `/workspaces/agency`, which **doesn't happen in newly onboarded projects**.

### Impact

New projects onboarded via cluster-templates will have:
- No speckit commands (`/specify`, `/clarify`, `/plan`, `/tasks`, `/implement`)
- No Agency MCP server (no `spec_kit.*` tools)
- Worker pipeline completely non-functional (phases return "Unknown skill")
- Zero error feedback (all failures suppressed by `2>/dev/null || true`)

### Root Cause

The entrypoint calls `generacy setup workspace` and `generacy setup build`, but:
1. `generacy setup workspace` clones repos based on the project's `.generacy/config.yaml` — agency may or may not be included
2. Even if agency IS in the config, `generacy setup build` Phase 4 only works if agency was successfully cloned AND built
3. All errors are silently swallowed

## Proposed Fix

### Short-term (until marketplace plugin exists — see generacy#310):
1. Ensure `agency` repo is always cloned in `generacy setup workspace` for dev containers that need speckit
2. Remove `2>/dev/null || true` from critical setup commands (or at minimum log errors to a file)
3. Add a pre-flight check in the worker entrypoint that verifies speckit commands exist before starting

### Long-term (after generacy#310):
1. Install speckit commands via `claude plugin install` from marketplace
2. Remove dependency on agency repo being locally available

## Files to Update

- `standard/.devcontainer/scripts/entrypoint-worker.sh`
- `standard/.devcontainer/scripts/entrypoint-orchestrator.sh`
- `microservices/.devcontainer/scripts/entrypoint-worker.sh`
- `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh`

## Related

- generacy#309 — Adds Phase 4 to `generacy setup build`
- generacy#310 — Marketplace plugin for speckit commands
- cluster-templates#3 — Worker entrypoint command update (separate issue)

## User Stories

### US1: New project onboarding with working speckit

**As a** developer onboarding a new project via cluster-templates,
**I want** speckit commands and the Agency MCP server to be automatically installed and configured,
**So that** my worker pipeline is functional from the first startup.

**Acceptance Criteria**:
- [ ] Agency repo is cloned during workspace setup regardless of project config
- [ ] Speckit slash commands are available after entrypoint completes
- [ ] Agency MCP server is configured and accessible
- [ ] Worker pipeline can execute phases without "Unknown skill" errors

### US2: Visible error feedback during setup

**As a** developer troubleshooting a failed onboarding,
**I want** setup errors to be logged and visible rather than silently suppressed,
**So that** I can diagnose and fix issues without guessing.

**Acceptance Criteria**:
- [ ] Critical setup command errors are logged to a file or stderr
- [ ] `2>/dev/null || true` is removed or replaced with proper error handling
- [ ] Setup failures produce actionable error messages

### US3: Pre-flight validation before worker start

**As a** cluster operator,
**I want** workers to verify speckit readiness before accepting tasks,
**So that** pipelines fail fast with a clear message instead of producing cryptic errors.

**Acceptance Criteria**:
- [ ] Worker entrypoint checks for speckit command availability before starting
- [ ] Missing speckit commands produce a clear error message with remediation steps
- [ ] Pre-flight check covers both slash commands and MCP server availability

## Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | Clone agency repo during workspace setup for speckit-dependent containers | P1 | Short-term fix |
| FR-002 | Replace silent error suppression with proper error logging | P1 | All 4 entrypoint scripts |
| FR-003 | Add pre-flight check for speckit commands in worker entrypoints | P1 | Fail fast with clear message |
| FR-004 | Ensure `generacy setup build` Phase 4 completes successfully | P1 | Depends on FR-001 |
| FR-005 | Log setup errors to `/tmp/generacy-setup.log` or similar | P2 | For debugging |

## Success Criteria

| ID | Metric | Target | Measurement |
|----|--------|--------|-------------|
| SC-001 | Speckit commands available after fresh onboarding | 100% | Run `/specify` in new cluster |
| SC-002 | Agency MCP server running after fresh onboarding | 100% | Check `spec_kit.*` tools available |
| SC-003 | Worker pipeline phase execution | No "Unknown skill" errors | Execute sample pipeline |
| SC-004 | Setup errors surfaced to user | All critical errors visible | Intentionally break setup, verify errors shown |

## Assumptions

- The `agency` repo is accessible from the dev container network
- `generacy setup build` Phase 4 logic is correct when agency repo is present
- Short-term fix is scoped to this repo; long-term marketplace solution is tracked in generacy#310

## Out of Scope

- Long-term marketplace plugin solution (generacy#310)
- Changes to `generacy setup build` itself (generacy repo)
- Changes to `.generacy/config.yaml` schema
- Worker entrypoint command update (cluster-templates#3)

---

*Generated by speckit*
