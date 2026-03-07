#!/usr/bin/env bash
# Initialize a cluster template for a specific project.
#
# Usage:
#   ./init-template.sh --name <project-name> --repo <repo-url> [--variant standard|microservices] [--repo-name <name>]
#
# If required arguments are not provided, the script will prompt interactively.

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────

PROJECT_NAME=""
REPO_URL=""
REPO_NAME=""
VARIANT="standard"

# ── Argument Parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --repo)
      REPO_URL="$2"
      shift 2
      ;;
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --repo-name)
      REPO_NAME="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --name <project-name> --repo <repo-url> [--variant standard|microservices] [--repo-name <name>]"
      echo ""
      echo "Options:"
      echo "  --name       Project name (used for container prefix and VS Code title)"
      echo "  --repo       Repository URL to clone into the cluster"
      echo "  --variant    Template variant: standard (default) or microservices"
      echo "  --repo-name  Override the repository directory name (default: derived from repo URL)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Interactive Prompts ──────────────────────────────────────────────────────

if [[ -z "$PROJECT_NAME" ]]; then
  read -rp "Project name: " PROJECT_NAME
fi

if [[ -z "$REPO_URL" ]]; then
  read -rp "Repository URL: " REPO_URL
fi

# ── Validation ───────────────────────────────────────────────────────────────

if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: Project name cannot be empty."
  exit 1
fi

if [[ -z "$REPO_URL" ]]; then
  echo "Error: Repository URL cannot be empty."
  exit 1
fi

if [[ "$VARIANT" != "standard" && "$VARIANT" != "microservices" ]]; then
  echo "Error: Variant must be 'standard' or 'microservices'."
  exit 1
fi

# ── Derive REPO_NAME ─────────────────────────────────────────────────────────

if [[ -z "$REPO_NAME" ]]; then
  REPO_NAME="$(basename "$REPO_URL" .git)"
fi

# ── Locate Target Directory ──────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/$VARIANT/.devcontainer"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: Variant directory not found: $TARGET_DIR"
  exit 1
fi

# ── Replace Placeholders ─────────────────────────────────────────────────────

TARGET_FILES=(
  "$TARGET_DIR/docker-compose.yml"
  "$TARGET_DIR/devcontainer.json"
  "$TARGET_DIR/.env"
)

for file in "${TARGET_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    sed -i.bak "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$file"
    sed -i.bak "s|{{REPO_NAME}}|$REPO_NAME|g" "$file"
    sed -i.bak "s|{{REPO_URL}}|$REPO_URL|g" "$file"
    rm -f "$file.bak"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Template initialized successfully!"
echo ""
echo "  Project name:  $PROJECT_NAME"
echo "  Repository:    $REPO_URL"
echo "  Repo name:     $REPO_NAME"
echo "  Variant:       $VARIANT"
echo ""
echo "Files updated:"
for file in "${TARGET_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    echo "  - ${file#"$SCRIPT_DIR/"}"
  fi
done
echo ""
echo "Next steps:"
echo "  1. Copy .env.local.template to .env.local and fill in your secrets"
echo "  2. Open the $VARIANT folder in VS Code with the Dev Containers extension"
