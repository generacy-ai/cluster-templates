# Cluster Templates

Dev container and Docker Compose templates for Generacy development clusters. Provides ready-to-use configurations for external developer onboarding.

## Repository Structure

- `standard/` - Standard variant: orchestrator with Docker-outside-of-Docker, headless workers, Redis
- `microservices/` - Microservices variant: adds Docker-in-Docker to all containers for running isolated Docker Compose stacks

Each variant contains a complete `.devcontainer/` setup (Dockerfile, docker-compose.yml, devcontainer.json, entrypoint scripts).

## Validating Changes

Build the Dockerfiles to verify they are valid:
```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

## MCP Testing Tools

For browser automation and testing capabilities, see:
[/workspaces/tetrad-development/docs/MCP_TESTING_TOOLS.md](/workspaces/tetrad-development/docs/MCP_TESTING_TOOLS.md)

## Development Stack

For shared services:
```bash
/workspaces/tetrad-development/scripts/stack start
source /workspaces/tetrad-development/scripts/stack-env.sh
```

See [/workspaces/tetrad-development/docs/DEVELOPMENT_STACK.md](/workspaces/tetrad-development/docs/DEVELOPMENT_STACK.md)
