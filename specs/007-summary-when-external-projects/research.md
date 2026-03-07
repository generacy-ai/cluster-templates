# Research: Template Placeholders and .env Split

## Technology Decisions

### Placeholder Syntax: `{{VARIABLE}}`

**Chosen**: Double-curly-brace syntax `{{VARIABLE}}`
**Rationale**: Docker Compose uses `${VAR}` for variable interpolation. Using `{{VAR}}` avoids any parsing conflicts — Docker Compose treats `{{VAR}}` as a literal string, so template files remain valid YAML even before initialization.

**Alternatives considered**:
- `__VARIABLE__` — less visually distinct, could conflict with Python dunder conventions
- `<VARIABLE>` — conflicts with XML/HTML in documentation
- `${VARIABLE}` — conflicts with Docker Compose variable interpolation

### Docker Compose `name:` for Project Isolation

**Chosen**: Top-level `name:` key (Compose v2 feature)
**Rationale**: The `name:` key sets the project name, which Docker Compose uses to prefix container names, network names, and volume names. This provides full namespace isolation without renaming services.

**How it works**:
```yaml
name: myproject
services:
  orchestrator:  # container: myproject-orchestrator-1
  worker:        # container: myproject-worker-1
  redis:         # container: myproject-redis-1
```

**Key behavior**:
- Container names: `{name}-{service}-{replica}`
- Network names: `{name}_{network}`
- Volume names: `{name}_{volume}`
- Overrides `COMPOSE_PROJECT_NAME` env var
- Supported since Docker Compose v2.0

### env_file Multi-File Loading

**Chosen**: Compose v2 `env_file` array with `required: false`
**Rationale**: Docker Compose v2.24+ supports the `required` field on env_file entries. This allows `.env.local` to be optional — containers start even if the user hasn't created it yet.

```yaml
env_file:
  - path: .env
  - path: .env.local
    required: false
```

**Note**: The `path:` key (vs bare string) is the v2 syntax. Older compose versions used bare strings only.

### sed for Placeholder Replacement

**Chosen**: GNU `sed -i` with basic regex
**Rationale**: Available on all target platforms (Linux, macOS via Homebrew, WSL). No additional runtime dependencies.

**Portability concern**: BSD sed (macOS default) requires `sed -i ''` while GNU sed uses `sed -i`. The init script should detect the platform or use a portable workaround:
```bash
sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file" && rm -f "$file.bak"
```

## Implementation Patterns

### Init Script Argument Parsing

Use `getopts` or manual flag parsing for:
```
--name <project-name>     Required
--repo <repo-url>         Required
--variant <standard|microservices>  Optional, default: standard
--repo-name <name>        Optional, derived from --repo
```

Interactive fallback: prompt for required values if not provided.

### REPO_NAME Derivation

```bash
# Extract repo name from URL
REPO_NAME=$(basename "$REPO_URL" .git)
# https://github.com/org/my-project.git → my-project
# git@github.com:org/my-project.git → my-project
```

### File Targeting

Only replace placeholders in known files to avoid unintended modifications:
```bash
TARGET_FILES=(
  "$VARIANT_DIR/.devcontainer/docker-compose.yml"
  "$VARIANT_DIR/.devcontainer/devcontainer.json"
  "$VARIANT_DIR/.devcontainer/.env"
)
```

## Key Sources

- [Docker Compose `name` specification](https://docs.docker.com/compose/how-tos/project-name/)
- [Docker Compose `env_file` specification](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)
- [POSIX sed portability](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sed.html)
