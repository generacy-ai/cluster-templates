# Quickstart: Speckit Setup Fix

## What Changed

This fix ensures speckit commands and the Agency MCP server are reliably installed during container onboarding. Three changes are made across all entrypoint scripts:

1. **New `setup-speckit.sh` script** — Ensures agency repo is cloned and speckit is properly installed
2. **Error logging** — Setup errors are logged to `/tmp/generacy-setup.log` instead of being suppressed
3. **Pre-flight check** — Workers verify speckit readiness before starting; fail fast if missing

## Verifying the Fix

### Build validation
```bash
docker build -f standard/.devcontainer/Dockerfile standard/.devcontainer/
docker build -f microservices/.devcontainer/Dockerfile microservices/.devcontainer/
```

### Check speckit availability (inside container)
```bash
# Slash commands installed?
ls ~/.claude/commands/specify.md

# MCP server configured?
grep -q "agency" ~/.claude/settings.json

# Setup log
cat /tmp/generacy-setup.log
```

### Simulate fresh onboarding
1. Start containers without pre-cloned agency repo
2. Watch logs for setup progress: `docker compose logs -f`
3. Verify workers start successfully (speckit available)
4. Verify orchestrator logs warning if speckit missing

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Worker exits with "Speckit commands not available" | Agency repo clone failed | Check network, `GH_TOKEN`, and `/tmp/generacy-setup.log` |
| "Unknown skill" in worker phases | Speckit slash commands not installed | Re-run `generacy setup build` manually inside container |
| MCP server not configured | `setup-speckit.sh` failed | Check `/tmp/generacy-setup.log`, verify agency repo at `/workspaces/agency` |
| Setup log empty | Setup completed successfully | No errors to log — this is expected |
