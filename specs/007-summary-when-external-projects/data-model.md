# Data Model: Template Placeholders and .env Split

## Template Variables

| Variable | Source | Required | Description |
|----------|--------|----------|-------------|
| `{{PROJECT_NAME}}` | User input | Yes | Project identifier used for compose project name, devcontainer name |
| `{{REPO_NAME}}` | Derived from REPO_URL or user input | Yes | Repository name used for workspaceFolder path |
| `{{REPO_URL}}` | User input | Yes | Git repository URL for cloning |

## Environment File Structure

### `.env` (Project Configuration — Checked In)

```env
# Project identity
PROJECT_NAME=<from init>
REPO_URL=<from init>
REPO_BRANCH=main

# Cluster configuration
WORKER_COUNT=3
ORCHESTRATOR_PORT=3100

# Optional features
MONITORED_REPOS=
LABEL_MONITOR_ENABLED=false
SMEE_CHANNEL_URL=
LOG_LEVEL=info
```

### `.env.local` (User Secrets — Gitignored)

```env
# GitHub credentials
GH_TOKEN=
GH_USERNAME=
GH_EMAIL=

# API keys
CLAUDE_API_KEY=
```

## File Transformation Map

Shows how each file changes from template state → initialized state.

### docker-compose.yml

| Field | Template Value | Initialized Value |
|-------|---------------|-------------------|
| `name` | `{{PROJECT_NAME}}` | `my-project` |
| `env_file` | `[.env, .env.local (optional)]` | Same (no change) |
| Service names | `orchestrator`, `worker`, `redis` | Same (unchanged) |

### devcontainer.json

| Field | Template Value | Initialized Value |
|-------|---------------|-------------------|
| `name` | `{{PROJECT_NAME}}` | `my-project` |
| `service` | `orchestrator` | Same (unchanged) |
| `workspaceFolder` | `/workspaces/{{REPO_NAME}}` | `/workspaces/my-project` |

## Docker Namespace Mapping

Given `PROJECT_NAME=myapp`:

| Resource | Template Name | Runtime Name |
|----------|--------------|--------------|
| Container (orchestrator) | — | `myapp-orchestrator-1` |
| Container (worker) | — | `myapp-worker-1` through `-N` |
| Container (redis) | — | `myapp-redis-1` |
| Network | `cluster-network` | `myapp_cluster-network` |
| Volume (workspace) | `workspace` | `myapp_workspace` |
| Volume (claude-config) | `claude-config` | `myapp_claude-config` |
| Volume (redis-data) | `redis-data` | `myapp_redis-data` |
