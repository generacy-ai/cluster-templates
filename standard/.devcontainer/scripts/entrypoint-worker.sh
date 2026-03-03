#!/bin/bash
# Entrypoint for Generacy worker containers
set -e

export AGENT_ID="${AGENT_ID:-$HOSTNAME}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [worker:${AGENT_ID}] $*"
}

log "Starting worker setup..."

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

# Start worker as PID 1
log "Starting worker ${AGENT_ID}..."
exec generacy worker \
    --worker-id "${AGENT_ID}" \
    --url "${ORCHESTRATOR_URL:-http://orchestrator:3100}" \
    --workdir "${WORKDIR:-/workspaces/project}" \
    --health-port "${HEALTH_PORT:-9001}"
