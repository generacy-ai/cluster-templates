#!/bin/bash
# Setup and verify speckit commands and Agency MCP server
# Usage:
#   setup-speckit.sh           # Run full setup (clone agency, build, re-run setup build)
#   setup-speckit.sh --verify  # Verify speckit is ready (exit 1 if not)

SETUP_LOG="${SETUP_LOG:-/tmp/generacy-setup.log}"
AGENCY_REPO_URL="${AGENCY_REPO_URL:-https://github.com/generacy-ai/agency}"
AGENCY_DIR="/workspaces/agency"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [setup-speckit] $*"
}

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

verify_speckit() {
    local ok=true

    # Check for representative slash command
    if [ ! -f "$HOME/.claude/commands/specify.md" ]; then
        log "VERIFY FAIL: ~/.claude/commands/specify.md not found"
        ok=false
    fi

    # Check for Agency MCP server entry in settings
    if [ ! -f "$HOME/.claude/settings.json" ]; then
        log "VERIFY FAIL: ~/.claude/settings.json not found"
        ok=false
    elif ! grep -q "agency" "$HOME/.claude/settings.json" 2>/dev/null; then
        log "VERIFY FAIL: agency MCP server not found in ~/.claude/settings.json"
        ok=false
    fi

    if [ "$ok" = true ]; then
        log "Speckit verification passed"
        return 0
    else
        return 1
    fi
}

# --verify mode: just check and exit
if [ "$1" = "--verify" ]; then
    verify_speckit
    exit $?
fi

# Full setup mode
log "Ensuring agency repo is available..."

# Check if agency repo exists, clone if missing
if [ ! -d "$AGENCY_DIR/.git" ]; then
    log "Agency repo not found at $AGENCY_DIR, cloning..."
    if ! clone_with_retry "$AGENCY_REPO_URL" "$AGENCY_DIR"; then
        log "ERROR: Failed to clone agency repo after 3 attempts"
        exit 1
    fi
    log "Agency repo cloned successfully"
else
    log "Agency repo already present at $AGENCY_DIR"
fi

# Build agency if needed (check for node_modules and dist)
if [ ! -d "$AGENCY_DIR/node_modules" ] || [ ! -d "$AGENCY_DIR/dist" ]; then
    log "Building agency..."
    cd "$AGENCY_DIR"
    npm install 2>>"$SETUP_LOG" || { log "ERROR: npm install failed in agency"; exit 1; }
    npm run build 2>>"$SETUP_LOG" || { log "ERROR: npm run build failed in agency"; exit 1; }
    log "Agency built successfully"
fi

# Re-run generacy setup build to trigger Phase 4
if command -v generacy >/dev/null 2>&1; then
    log "Re-running generacy setup build..."
    generacy setup build 2>>"$SETUP_LOG" || {
        log "ERROR: generacy setup build failed"
        exit 1
    }
    log "generacy setup build completed"
fi

# Verify the result
if verify_speckit; then
    log "Setup complete — speckit is ready"
else
    log "WARNING: Setup completed but verification failed"
    exit 1
fi
