# Implementation Plan: Port Shared Volume Package Install Approach with Release Channels

**Feature**: Install generacy/agency packages from npm into a shared volume at startup; workers use wrapper scripts
**Branch**: `012-summary-adopt-shared-volume`
**Status**: Complete
**Issue**: #12

## Summary

Remove baked-in generacy/agency packages from Docker images. Instead, the orchestrator installs them from npm into a shared volume (`/shared-packages`) at container startup. Workers mount the volume read-only and access CLIs via thin wrapper scripts in `~/.local/bin/`. Supports configurable release channels (`stable`/`preview`) and a skip mechanism for fast restarts.

## Technical Context

- **Language**: Bash (shell scripts), YAML (Docker Compose)
- **Runtime**: Docker containers (Debian bookworm, node user)
- **Dependencies**: npm, node, generacy CLI, nc (netcat)
- **Variants**: Standard and Microservices (identical changes to both)

## Clarifications (Resolved)

All five clarifications have been answered:
- **Q1 (Mount path)**: `/shared-packages` — consistent with tetrad-development
- **Q2 (Packages to install)**: All three — `@generacy-ai/generacy`, `@generacy-ai/agency`, `@generacy-ai/agency-plugin-spec-kit`
- **Q3 (Version-match skip)**: Marker file at `/shared-packages/.installed-version` (no network required)
- **Q4 (npm cache path)**: `/home/node/.npm` (default; no extra config needed)
- **Q5 (Worker wrapper targets)**: `node_modules/.bin/` symlinks managed by npm

## Project Structure

```
standard/.devcontainer/
├── Dockerfile                          ← MODIFY: remove tooling stage npm installs
├── docker-compose.yml                  ← MODIFY: add shared-packages + npm-cache volumes
└── scripts/
    ├── entrypoint-orchestrator.sh      ← MODIFY: add npm install + marker file logic
    ├── entrypoint-worker.sh            ← MODIFY: add wrapper scripts + PATH setup
    └── setup-speckit.sh               ← MODIFY: replace git clone with npm install

microservices/.devcontainer/
├── Dockerfile                          ← MODIFY: remove tooling stage npm installs
├── docker-compose.yml                  ← MODIFY: add shared-packages + npm-cache volumes
└── scripts/
    ├── entrypoint-orchestrator.sh      ← MODIFY: same changes
    ├── entrypoint-worker.sh            ← MODIFY: same changes
    └── setup-speckit.sh               ← MODIFY: same changes
```

## Implementation Steps

### Step 1: Update Dockerfiles — remove baked-in packages

Remove the "Generacy tooling" stage (`tooling`) that runs `npm install -g @generacy-ai/generacy@preview @generacy-ai/agency@preview`. Packages will be installed at runtime instead.

Keep the stage boundary intact (rename `tooling` to be skipped or merge into `final`). Claude Code install and PATH setup remain in the image.

**What changes**:
- Delete or skip the `RUN npm install -g @generacy-ai/generacy@preview @generacy-ai/agency@preview` line
- Stage names: collapse `tooling` → `final` (or keep stage names for cache clarity and just remove the npm install RUN)

**Files modified** (2):
- `standard/.devcontainer/Dockerfile`
- `microservices/.devcontainer/Dockerfile`

### Step 2: Update docker-compose.yml — add volumes and env vars

**Add two named volumes** (both variants):

```yaml
volumes:
  shared-packages:   # orchestrator writes; workers read
  npm-cache:         # speeds up repeated npm installs
  workspace:         # existing
  claude-config:     # existing
  redis-data:        # existing
```

**Mount volumes into services**:

Orchestrator:
```yaml
volumes:
  - shared-packages:/shared-packages    # read-write: orchestrator installs here
  - npm-cache:/home/node/.npm           # npm cache persistence
  # ... existing mounts
```

Worker:
```yaml
volumes:
  - shared-packages:/shared-packages:ro # read-only: workers consume packages
  # ... existing mounts
```

**Add env vars** to orchestrator and worker environment sections:
```yaml
environment:
  - GENERACY_CHANNEL=${GENERACY_CHANNEL:-stable}
  - SKIP_PACKAGE_UPDATE=${SKIP_PACKAGE_UPDATE:-false}
```

**Files modified** (2):
- `standard/.devcontainer/docker-compose.yml`
- `microservices/.devcontainer/docker-compose.yml`

### Step 3: Update orchestrator entrypoint — npm install with skip logic

Insert a package install block **before** the `generacy setup` calls. This ensures packages are available when `generacy` is invoked.

```bash
# Install generacy/agency packages into shared volume
SHARED_PACKAGES=/shared-packages
CHANNEL="${GENERACY_CHANNEL:-stable}"
MARKER_FILE="${SHARED_PACKAGES}/.installed-version"

install_packages() {
    log "Installing @generacy-ai packages (channel: ${CHANNEL}) into ${SHARED_PACKAGES}..."
    npm install \
        --prefix "${SHARED_PACKAGES}" \
        --no-save \
        "@generacy-ai/generacy@${CHANNEL}" \
        "@generacy-ai/agency@${CHANNEL}" \
        "@generacy-ai/agency-plugin-spec-kit@${CHANNEL}" \
        2>>"$SETUP_LOG" || { log "ERROR: npm install failed"; exit 1; }
    # Write marker: channel + installed version of generacy
    local version
    version=$(node -e "console.log(require('${SHARED_PACKAGES}/node_modules/@generacy-ai/generacy/package.json').version)" 2>/dev/null || echo "unknown")
    echo "${CHANNEL}:${version}" > "${MARKER_FILE}"
    log "Packages installed (version: ${version})"
}

if [ "${SKIP_PACKAGE_UPDATE:-false}" = "true" ]; then
    log "SKIP_PACKAGE_UPDATE=true — skipping npm install"
elif [ -f "${MARKER_FILE}" ]; then
    MARKER=$(cat "${MARKER_FILE}")
    if [ "${MARKER%:*}" = "${CHANNEL}" ]; then
        log "Packages already installed for channel '${CHANNEL}' (${MARKER#*:}) — skipping"
    else
        log "Channel changed from '${MARKER%:*}' to '${CHANNEL}' — reinstalling"
        install_packages
    fi
else
    install_packages
fi

# Add shared packages to PATH for this process
export PATH="${SHARED_PACKAGES}/node_modules/.bin:${PATH}"
```

**Files modified** (2):
- `standard/.devcontainer/scripts/entrypoint-orchestrator.sh`
- `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh`

### Step 4: Update worker entrypoint — wrapper scripts + PATH

Workers mount the volume read-only. They cannot run `npm install` or `npm link`. Instead, create thin wrapper scripts that exec the CLI entry points via the `node_modules/.bin/` symlinks that npm manages.

Insert this block **early in the worker entrypoint**, before `generacy` is first invoked:

```bash
# Set up CLI wrappers pointing to shared packages volume
SHARED_PACKAGES=/shared-packages
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"

for cli in generacy agency; do
    WRAPPER="${LOCAL_BIN}/${cli}"
    cat > "${WRAPPER}" <<EOF
#!/bin/sh
exec node ${SHARED_PACKAGES}/node_modules/.bin/${cli} "\$@"
EOF
    chmod +x "${WRAPPER}"
done

# Ensure ~/.local/bin is on PATH for this process and subprocesses
export PATH="${LOCAL_BIN}:${PATH}"
if ! grep -q 'local/bin' "${HOME}/.bashrc" 2>/dev/null; then
    echo 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.bashrc"
fi

log "CLI wrappers created in ${LOCAL_BIN}"
```

**Files modified** (2):
- `standard/.devcontainer/scripts/entrypoint-worker.sh`
- `microservices/.devcontainer/scripts/entrypoint-worker.sh`

### Step 5: Update setup-speckit.sh — replace git clone with npm install

Replace the `clone_with_retry` + build section with an `npm install -g` call:

```bash
# Full setup mode — recover speckit via npm (no git clone needed)
log "Installing @generacy-ai/agency-plugin-spec-kit from npm..."
npm install -g @generacy-ai/agency-plugin-spec-kit 2>>"$SETUP_LOG" || {
    log "ERROR: npm install -g @generacy-ai/agency-plugin-spec-kit failed"
    exit 1
}
log "agency-plugin-spec-kit installed"

# Re-run generacy setup build to trigger Phase 4 (copies command files)
if command -v generacy >/dev/null 2>&1; then
    log "Re-running generacy setup build..."
    generacy setup build 2>>"$SETUP_LOG" || {
        log "ERROR: generacy setup build failed"
        exit 1
    }
fi
```

Remove: `AGENCY_REPO_URL`, `AGENCY_DIR`, `clone_with_retry` function, and the build step that runs `npm install && npm run build` in the cloned repo.

**Files modified** (2):
- `standard/.devcontainer/scripts/setup-speckit.sh`
- `microservices/.devcontainer/scripts/setup-speckit.sh`

### Step 6: Validate with Docker build

```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Volume mount path | `/shared-packages` | Matches tetrad-development; short, self-documenting |
| Package install mechanism | `npm install --prefix /shared-packages` | Installs into shared volume without global side effects |
| Worker CLI access | Wrapper scripts in `~/.local/bin/` exec `node_modules/.bin/` | Avoids EROFS from `npm link`; npm manages symlinks automatically |
| Version-match skip | Marker file at `/shared-packages/.installed-version` | No network required; works offline; fast on restart |
| Channel format | `GENERACY_CHANNEL=stable\|preview` maps to npm dist-tag | Natural mapping; dist-tags allow independent stable/preview streams |
| npm cache | Named volume at `/home/node/.npm` | Default npm cache location for node user; no extra config |
| speckit recovery | `npm install -g @generacy-ai/agency-plugin-spec-kit` | Eliminates git clone; package bundles command files already |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| npm publish not done before implementation | Workers cannot start | Spec explicitly notes packages must be published first; implementation blocked until then |
| Shared volume not ready when workers start | Workers can't find CLIs | Workers depend on orchestrator healthcheck; orchestrator installs before becoming healthy |
| EROFS on shared overlayfs | Worker npm operations fail | Wrapper scripts avoid all write operations on the shared volume |
| Marker file channel mismatch detection | Wrong packages used | Marker stores `channel:version`; channel change forces reinstall |
| `.bashrc` PATH not applied to Claude subprocesses | CLIs not found in subshells | Both `export PATH=...` (current process) and `.bashrc` append (new shells) applied |

## Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `standard/.devcontainer/Dockerfile` | Modify | Remove `npm install -g` tooling stage |
| `standard/.devcontainer/docker-compose.yml` | Modify | Add `shared-packages` + `npm-cache` volumes; add env vars |
| `standard/.devcontainer/scripts/entrypoint-orchestrator.sh` | Modify | Add npm install block with skip/marker logic |
| `standard/.devcontainer/scripts/entrypoint-worker.sh` | Modify | Add wrapper script creation + PATH setup |
| `standard/.devcontainer/scripts/setup-speckit.sh` | Modify | Replace git clone+build with `npm install -g` |
| `microservices/.devcontainer/Dockerfile` | Modify | Same as standard |
| `microservices/.devcontainer/docker-compose.yml` | Modify | Same as standard |
| `microservices/.devcontainer/scripts/entrypoint-orchestrator.sh` | Modify | Same as standard |
| `microservices/.devcontainer/scripts/entrypoint-worker.sh` | Modify | Same as standard |
| `microservices/.devcontainer/scripts/setup-speckit.sh` | Modify | Same as standard |

---

*Generated by speckit*
