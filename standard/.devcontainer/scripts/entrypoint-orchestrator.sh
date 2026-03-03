#!/bin/bash
# Entrypoint for the Generacy orchestrator container
set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [orchestrator] $*"
}

log "Starting orchestrator setup..."

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
    log "Running generacy setup..."
    generacy setup auth 2>/dev/null || true
    generacy setup workspace --clean 2>/dev/null || true
    generacy setup build 2>/dev/null || true
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
