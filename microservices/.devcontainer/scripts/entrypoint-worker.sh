#!/bin/bash
# Entrypoint for Generacy worker containers (microservices variant)
# Starts Docker-in-Docker so the worker can run its own container stacks
set -e

export AGENT_ID="${AGENT_ID:-$HOSTNAME}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [worker:${AGENT_ID}] $*"
}

log "Starting worker setup..."

# Setup Docker-in-Docker (each worker gets its own isolated Docker daemon)
if [ -x "/usr/local/bin/setup-docker-dind.sh" ]; then
    bash /usr/local/bin/setup-docker-dind.sh
fi

# Configure git credentials
bash /usr/local/bin/setup-credentials.sh

# Clone project repo if workspace is fresh
if [ -n "${REPO_URL:-}" ] && [ ! -d "/workspaces/project/.git" ]; then
    log "Cloning project repo: ${REPO_URL} (branch: ${REPO_BRANCH:-main})"
    git clone --branch "${REPO_BRANCH:-main}" "${REPO_URL}" /workspaces/project
elif [ -d "/workspaces/project/.git" ]; then
    log "Project repo already cloned, pulling latest..."
    cd /workspaces/project
    git fetch origin
    git pull --ff-only origin "${REPO_BRANCH:-main}" 2>/dev/null || true
fi

# Run generacy setup if CLI is available
if command -v generacy >/dev/null 2>&1; then
    SETUP_LOG="/tmp/generacy-setup.log"
    log "Running generacy setup..."

    # Non-critical: log errors but continue
    generacy setup auth 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup auth' failed (see $SETUP_LOG)"

    # Important: log errors but continue (workspace needed for build)
    generacy setup workspace --clean 2>>"$SETUP_LOG" || log "WARNING: 'generacy setup workspace' failed (see $SETUP_LOG)"

    # Critical: trigger speckit recovery on failure
    generacy setup build 2>>"$SETUP_LOG" || {
        log "ERROR: 'generacy setup build' failed — attempting speckit recovery (see $SETUP_LOG)"
        bash /usr/local/bin/setup-speckit.sh 2>>"$SETUP_LOG" || log "ERROR: speckit recovery also failed (see $SETUP_LOG)"
    }
fi

# Pre-flight: verify speckit readiness
if [ -x "/usr/local/bin/setup-speckit.sh" ]; then
    if ! bash /usr/local/bin/setup-speckit.sh --verify; then
        log "FATAL: Speckit commands not available. Worker cannot process phases."
        log "FATAL: Check ${SETUP_LOG:-/tmp/generacy-setup.log} for setup errors."
        log "FATAL: Ensure agency repo is accessible and 'generacy setup build' succeeds."
        exit 1
    fi
fi

# Start worker as PID 1
log "Starting worker ${AGENT_ID}..."
exec generacy orchestrator \
    --port "${HEALTH_PORT:-9001}" \
    --redis-url "redis://${REDIS_HOST:-redis}:${REDIS_PORT:-6379}" \
    --worker-only
