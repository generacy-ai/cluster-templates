# Quickstart: Template Initialization

## Prerequisites

- Docker and Docker Compose v2 installed
- Git installed
- Bash shell (Linux, macOS, WSL)

## Getting Started

### 1. Clone the Template

```bash
git clone https://github.com/generacy-ai/cluster-templates.git my-project
cd my-project
```

### 2. Initialize the Template

**Interactive mode:**
```bash
./init-template.sh
# Prompts for project name and repo URL
```

**Non-interactive mode:**
```bash
./init-template.sh --name my-project --repo https://github.com/org/my-project.git
```

**With options:**
```bash
./init-template.sh \
  --name my-project \
  --repo https://github.com/org/my-project.git \
  --variant microservices \
  --repo-name custom-name
```

### 3. Configure Secrets

```bash
cd standard/.devcontainer   # or microservices/.devcontainer
cp .env.local.template .env.local
# Edit .env.local with your tokens:
#   GH_TOKEN=ghp_...
#   GH_USERNAME=your-username
#   GH_EMAIL=your@email.com
#   CLAUDE_API_KEY=sk-ant-...
```

### 4. Open in VS Code

```bash
code standard/   # or microservices/
# VS Code will detect .devcontainer and offer to reopen in container
```

## Available Commands

```
./init-template.sh [OPTIONS]

Options:
  --name <name>       Project name (used for container names, compose project)
  --repo <url>        Git repository URL to clone into the workspace
  --variant <type>    Template variant: standard (default) or microservices
  --repo-name <name>  Override auto-derived repository name
  --help              Show usage information
```

## Multi-Project Setup

When running multiple projects simultaneously on the same Docker host:

1. Each project must have a unique `PROJECT_NAME`
2. Each project must use a different `ORCHESTRATOR_PORT` in `.env`
3. Update `forwardPorts` in `devcontainer.json` to match the custom port

Example for a second project:
```bash
# In second project's .env:
ORCHESTRATOR_PORT=3200

# In second project's devcontainer.json, update forwardPorts:
"forwardPorts": [3200, 6379]
```

## Troubleshooting

### Containers won't start — `.env.local` missing
Containers start without `.env.local` (it's optional), but functionality requiring tokens (GitHub access, Claude API) won't work. Create `.env.local` from the template.

### Container name conflicts
If you see "container name already in use", another project may be using the same `PROJECT_NAME`. Check with `docker ps` and use a unique name.

### Placeholder `{{...}}` still visible after init
Re-run `init-template.sh` or check that you're editing files in the correct variant directory.

### macOS sed errors
If `sed` reports errors on macOS, install GNU sed: `brew install gnu-sed` and use `gsed` or ensure the init script's portable sed workaround is working.
