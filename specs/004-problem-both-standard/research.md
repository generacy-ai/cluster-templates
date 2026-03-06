# Research: Speckit Setup Fix

## Technology Decisions

### 1. Agency Clone Strategy: Check-then-clone (Option C)

**Decision**: After `generacy setup workspace` runs, check if `/workspaces/agency` exists. If not, clone it directly.

**Rationale**:
- Doesn't require changes to the `generacy` CLI (out of scope)
- Doesn't assume CLI flags like `--include agency` exist
- Idempotent — safe to run repeatedly
- Follows existing entrypoint pattern of conditional execution

**Alternatives considered**:
- Direct hardcoded clone (Option A): Would always clone even if workspace setup already handled it
- CLI flag (Option B): Would require changes to the generacy CLI repo, which is out of scope

### 2. Error Handling: Selective fail-hard (Option C)

**Decision**: `setup auth` logs warnings and continues. `setup build` triggers recovery on failure.

**Rationale**:
- Auth failures are often transient (token refresh, network) and shouldn't prevent startup
- Build failures directly cause the speckit problem — must be surfaced
- Logging to `/tmp/generacy-setup.log` provides debugging without cluttering stdout
- Container can still start for manual debugging even if non-critical steps fail

**Alternatives considered**:
- Fail hard on everything (Option A): Too aggressive; auth issues would prevent container startup entirely
- Log everything and continue (Option B): Masks the exact problem this issue is fixing

### 3. Pre-flight Verification: File-based checks

**Decision**: Check for specific files rather than running test commands.

**Rationale**:
- File existence checks are fast and deterministic
- Slash commands are installed as files in `~/.claude/commands/`
- MCP server config is in `~/.claude/settings.json`
- No need to start/stop services for verification

**What to check**:
- `~/.claude/commands/specify.md` (representative slash command)
- `~/.claude/settings.json` contains `agency` MCP server entry (via grep)

## Implementation Patterns

### Retry with backoff for git clone

```bash
clone_with_retry() {
    local url="$1" dest="$2" max_attempts=3 attempt=1
    while [ $attempt -le $max_attempts ]; do
        if git clone "$url" "$dest" 2>>"$SETUP_LOG"; then
            return 0
        fi
        log "WARNING: Clone attempt $attempt/$max_attempts failed, retrying in ${attempt}s..."
        sleep $attempt
        attempt=$((attempt + 1))
    done
    return 1
}
```

### Selective error handling pattern

```bash
# Non-critical: warn on failure
command 2>>"$LOG" || log "WARNING: command failed"

# Critical with recovery: attempt fix
command 2>>"$LOG" || { log "ERROR: command failed"; recover; }

# Fatal: exit container
command 2>>"$LOG" || { log "FATAL: command failed"; exit 1; }
```

## Key References

- `generacy setup build` Phase 4: Installs speckit slash commands and configures Agency MCP server
- Agency repo expected at: `/workspaces/agency`
- Slash commands installed to: `~/.claude/commands/`
- MCP server config in: `~/.claude/settings.json`
- Related issues: generacy#309 (Phase 4), generacy#310 (marketplace long-term fix)
