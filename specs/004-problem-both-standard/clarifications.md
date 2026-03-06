# Clarifications

Questions and answers to clarify the feature specification.

## Batch 1 - 2026-03-06 20:30

### Q1: Agency repo clone mechanism
**Context**: FR-001 requires cloning the agency repo, but the spec says changes to `.generacy/config.yaml` schema are out of scope. The entrypoint needs to clone agency independently, but we need to know the repo URL and target path.
**Question**: How should the entrypoint clone the agency repo? Should it use a hardcoded git clone to a known URL (e.g., `git clone https://github.com/generacy-ai/agency /workspaces/agency`), or is there a generacy CLI command that can force-clone agency specifically?
**Options**:
- A: Direct `git clone` with hardcoded org URL (e.g., `https://github.com/generacy-ai/agency`)
- B: Use a generacy CLI flag like `generacy setup workspace --include agency`
- C: Check if `/workspaces/agency` exists after `generacy setup workspace`, and only clone manually if missing

**Answer**: *Pending*

### Q2: Error handling strategy with set -e
**Context**: All entrypoints use `set -e` at the top. Removing `|| true` from `generacy setup auth/workspace/build` would cause the container to exit immediately on any setup failure. This could prevent the container from starting at all, which may or may not be desired.
**Question**: When a setup command fails, should the container fail to start (remove `|| true` entirely, letting `set -e` kill it), or should errors be logged to a file while allowing startup to continue?
**Options**:
- A: Fail hard — remove `|| true` so any setup failure prevents the container from starting
- B: Log and continue — redirect stderr to a log file but keep `|| true` so the container always starts
- C: Selective — fail hard on critical commands (setup build), log-and-continue on non-critical (setup auth)

**Answer**: *Pending*

### Q3: Pre-flight check specifics
**Context**: FR-003 requires a pre-flight check for speckit command availability before workers start. The check needs to verify specific artifacts, but the spec doesn't detail what constitutes 'speckit readiness' or where speckit installs its commands.
**Question**: What specific checks should the pre-flight validation perform? For example: check for specific files in `~/.claude/commands/`, verify the MCP server config in `~/.claude/settings.json`, run a test command, or something else?
**Options**:
- A: Check for speckit command files in `~/.claude/commands/` (e.g., `specify.md`, `clarify.md`)
- B: Check for Agency MCP server entry in Claude settings/config
- C: Both A and B — verify both slash commands and MCP server configuration

**Answer**: *Pending*

### Q4: Pre-flight failure behavior
**Context**: US3 says workers should 'fail fast with a clear message' but doesn't specify whether this means the container should exit (preventing the worker from starting at all) or just log a warning and start anyway.
**Question**: If the pre-flight check fails (speckit not available), should the worker container exit with an error (preventing it from joining the cluster), or should it start with a degraded status and log a warning?
**Options**:
- A: Exit with error — worker refuses to start without speckit (fail-fast)
- B: Log warning and start — worker joins cluster but logs that speckit is missing
- C: Retry with backoff — attempt to install speckit a few times before giving up

**Answer**: *Pending*

### Q5: Orchestrator pre-flight scope
**Context**: US3 and FR-003 mention pre-flight checks specifically for 'worker entrypoints', but the orchestrator also runs `generacy setup build` and may need speckit for label monitoring or task dispatch. The spec lists all 4 entrypoints under 'Files to Update'.
**Question**: Should the orchestrator entrypoints also include the pre-flight speckit check, or is this only needed for workers?
**Options**:
- A: Workers only — orchestrator doesn't directly use speckit commands
- B: Both workers and orchestrator — ensure consistency across all containers
- C: Workers get full pre-flight check, orchestrator gets a lighter version (just error logging)

**Answer**: *Pending*

