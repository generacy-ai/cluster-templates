# Clarifications: Feature #12 — Port Shared Volume Package Install Approach

## Batch 1 — 2026-03-08

### Q1: Shared Volume Mount Path
**Context**: The shared package volume must be mounted at a consistent path in all containers (orchestrator writes, workers read). All entrypoint scripts and wrapper scripts depend on this path. The spec says workers mount the volume "at the same mount path" but never defines what that path is.
**Question**: What path should the shared package volume be mounted at inside containers (e.g., `/shared/packages`, `/opt/packages`, `/home/node/.shared-packages`)?

**Answer**: `/shared-packages` — consistent with what tetrad-development already uses, short, self-documenting, doesn't conflict with user home or system paths.

---

### Q2: npm Packages to Install
**Context**: The Dockerfiles currently install `@generacy-ai/generacy@preview` and `@generacy-ai/agency@preview`. The spec's assumptions mention `@generacy-ai/generacy` and `@generacy-ai/agency-plugin-spec-kit` — notably `agency-plugin-spec-kit`, not `agency`. Workers need both the `generacy` and `agency` CLIs to function.
**Question**: Which npm packages should the orchestrator install into the shared volume? Options:
- A: `@generacy-ai/generacy` + `@generacy-ai/agency` (same as current Dockerfile, just moved to runtime)
- B: `@generacy-ai/generacy` + `@generacy-ai/agency-plugin-spec-kit` (as listed in spec assumptions)
- C: All three: `@generacy-ai/generacy` + `@generacy-ai/agency` + `@generacy-ai/agency-plugin-spec-kit`

**Answer**: Option C — all three. `@generacy-ai/generacy` is the CLI, `@generacy-ai/agency` is the MCP server (needed for Claude Code integration), and `@generacy-ai/agency-plugin-spec-kit` provides the speckit command `.md` files. They serve different purposes and all are needed for a functioning setup.

---

### Q3: Version-Match Skip Mechanism
**Context**: FR-005 requires skipping npm install when the installed version already matches the requested version. The spec doesn't define how to compare versions. Two main approaches: (a) write a marker file with the installed version at install time and compare on next startup (no network); (b) query the npm registry for the dist-tag version and compare against installed (requires network). The dist-tag approach requires a network call even to check, partially defeating the skip optimization.
**Question**: How should the version-match check (FR-005) work?
- A: Write a marker file (e.g., `/shared/packages/.installed-version`) at install time; compare on startup without network
- B: Query npm registry for the dist-tag version; compare against installed version (requires network)
- C: Other approach?

**Answer**: Option A — marker file. Write the installed version + channel to `/shared-packages/.installed-version` at install time. On startup, compare without network. Fast, works offline, and aligns with the `SKIP_PACKAGE_UPDATE=true` intent. Users can force an update by deleting the marker or setting the env var.

---

### Q4: npm Cache Volume Mount Path
**Context**: FR-003 adds a named npm cache volume. The node user's home is `/home/node`, so the default npm cache would be `/home/node/.npm`. However, since containers run as `node` user, a custom path mounted to `/home/node/.npm` or another location must be specified in docker-compose.yml.
**Question**: Where should the npm cache volume be mounted inside containers? Options:
- A: `/home/node/.npm` (default npm cache for node user)
- B: A custom path like `/var/cache/npm` (needs `npm config set cache` in entrypoint)
- C: Let npm auto-determine and just mount a volume at `/home/node/.npm`

**Answer**: Option A — `/home/node/.npm`. It's the default npm cache location for the node user, so no extra `npm config set` is needed. Just mount a named volume there in compose.

---

### Q5: Worker Wrapper Script CLI Targets
**Context**: FR-008 requires wrapper scripts in `~/.local/bin/` pointing to CLI entry points within the shared volume. The exact paths depend on npm package structure (e.g., `node_modules/@generacy-ai/generacy/bin/generacy.js`). The implementation needs to know either the hardcoded paths or whether to discover them dynamically.
**Question**: Should wrapper scripts reference hardcoded paths within the npm package (e.g., `node /shared/packages/node_modules/@generacy-ai/generacy/bin/generacy.js`), or should the entrypoint discover CLI paths dynamically using `npm bin` or `node_modules/.bin/` symlinks?
- A: Hardcoded paths (simpler, but breaks if package internals change)
- B: Use `node_modules/.bin/` symlinks in the shared volume (let npm manage binary links, workers exec the symlink target)
- C: Dynamic discovery via `npm prefix` / `npm bin` at entrypoint startup

**Answer**: Option B — use `node_modules/.bin/` symlinks. npm manages these automatically when packages are installed, so wrapper scripts reference e.g. `/shared-packages/node_modules/.bin/generacy`. More resilient than hardcoding internal package paths, avoids overhead of dynamic discovery at startup.
