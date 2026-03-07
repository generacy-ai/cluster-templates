#!/bin/bash
# Entrypoint for the Generacy orchestrator container (microservices variant)
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [orchestrator] $*"
}

log "Starting orchestrator setup..."

# Setup Docker-in-Docker and contexts
if [ -x "/usr/local/bin/setup-docker-dind.sh" ]; then
    bash /usr/local/bin/setup-docker-dind.sh
fi

# Configure git credentials
bash /usr/local/bin/setup-credentials.sh

# Resolve workspace directory (handles devcontainer detection + clone)
source /usr/local/bin/resolve-workspace.sh

# Run generacy setup if CLI is available
if command -v generacy >/dev/null 2>&1; then
    SETUP_LOG="/tmp/generacy-setup.log"
    log "Running generacy setup..."

    # Non-critical: log errors but continue
    generacy setup auth 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup auth' failed (see $SETUP_LOG)"

    # Important: log errors but continue (workspace needed for build)
    # Pass --config when config file exists to avoid ambiguity with multiple repos
    CONFIG_PATH="${WORKSPACE_DIR}/.generacy/config.yaml"
    if [ -f "$CONFIG_PATH" ]; then
        generacy setup workspace --config "$CONFIG_PATH" --clean 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup workspace' failed (see $SETUP_LOG)"
    else
        generacy setup workspace --clean 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup workspace' failed (see $SETUP_LOG)"
    fi

    # Critical: trigger speckit recovery on failure
    generacy setup build 2>>"$SETUP_LOG" || {
        log "ERROR: 'generacy setup build' failed — attempting speckit recovery (see $SETUP_LOG)"
        bash /usr/local/bin/setup-speckit.sh 2>>"$SETUP_LOG" || log "ERROR: speckit recovery also failed (see $SETUP_LOG)"
    }
fi

# Light check: warn if speckit is missing (orchestrator can still run)
if [ -x "/usr/local/bin/setup-speckit.sh" ]; then
    if ! bash /usr/local/bin/setup-speckit.sh --verify 2>/dev/null; then
        log "WARNING: Speckit commands not available. Workers may fail to process phases."
    fi
fi

# Wait for Redis to be ready
log "Waiting for Redis at ${REDIS_HOST:-redis}:6379..."
while ! nc -z "${REDIS_HOST:-redis}" 6379 2>/dev/null; do
    sleep 1
done
log "Redis is ready"

# Start orchestrator as PID 1
log "Starting orchestrator on port ${ORCHESTRATOR_PORT:-3100}..."
exec generacy orchestrator \
    --port "${ORCHESTRATOR_PORT:-3100}" \
    --redis-url "${REDIS_URL:-redis://redis:6379}" \
    ${LABEL_MONITOR_ENABLED:+--label-monitor}
