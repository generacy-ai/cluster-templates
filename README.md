# Generacy Cluster Templates

Development cluster templates for [Generacy](https://generacy.ai). Each template provides a complete, isolated development environment with an orchestrator, scalable workers, and Redis for state management.

## Variants

### Standard

For applications that **do not** run containers/microservices themselves.

- Orchestrator with Docker-outside-of-Docker (manages worker containers)
- Headless Claude Code workers (no Docker daemon)
- Local Redis for inter-service communication
- Isolated network and scoped credentials

**Use when:** Your app is a web app, API, library, or anything that doesn't need `docker compose` inside workers.

### Microservices

For applications that **run their own containers** (Docker Compose stacks, microservices, etc.).

Everything in Standard, plus:

- Docker-in-Docker in every container (orchestrator + workers)
- Each worker can spin up isolated `docker compose` stacks
- Privileged containers for DinD support
- Docker context management (DinD for app services, DooD for cluster management)

**Use when:** Your app uses Docker Compose, runs microservices, or needs container orchestration during development.

## Quick Start

1. **Copy the template** into your project:

   ```bash
   # Standard
   cp -r standard/.devcontainer /path/to/your/project/

   # Or Microservices
   cp -r microservices/.devcontainer /path/to/your/project/
   ```

2. **Configure environment:**

   ```bash
   cd /path/to/your/project/.devcontainer
   cp .env.template .env
   # Edit .env with your values (GH_TOKEN, REPO_URL, etc.)
   ```

3. **Open in VS Code** with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers), or start directly:

   ```bash
   cd /path/to/your/project/.devcontainer
   docker compose up -d
   ```

## Template Structure

```
.devcontainer/
├── Dockerfile              # Multi-stage build (customize for your project)
├── docker-compose.yml      # Orchestrator + workers + Redis
├── devcontainer.json       # VS Code Dev Container configuration
├── .env.template           # Environment variable template
└── scripts/
    ├── entrypoint-orchestrator.sh
    ├── entrypoint-worker.sh
    ├── setup-credentials.sh
    └── setup-docker-dind.sh    # Microservices variant only
```

## Key Design Decisions

### Isolation

- **Network:** Each cluster runs on its own bridge network, isolated from other containers on the host.
- **Credentials:** GitHub tokens are scoped and injected via `.env`, never mounted from the host credential store.
- **Volumes:** Repos are cloned into Docker volumes (not bind-mounted from the host) for isolation and cross-platform compatibility.
- **Claude config:** Shared across orchestrator and workers via a dedicated volume so all agents use the same API keys and settings.

### Customization

The Dockerfile uses multi-stage builds for efficient caching. Add your project's dependencies in the marked customization section at the bottom — your changes will rebuild quickly since the tooling layers above are cached.

### Scaling

Worker count is controlled by the `WORKER_COUNT` environment variable (default: 3). Change it in your `.env` file or override at runtime:

```bash
WORKER_COUNT=5 docker compose up -d
```

## Requirements

- Docker Desktop or Docker Engine with Compose v2
- VS Code with [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) (optional, for IDE integration)
- A GitHub personal access token with `repo`, `workflow`, and `read:org` scopes
