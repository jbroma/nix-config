#!/usr/bin/env bash
# Update all Claude Code marketplaces and plugins

set -euo pipefail

echo "=== Updating marketplaces ==="
claude plugin marketplace update

echo ""
echo "=== Updating plugins ==="
plugins=$(jq -r '.plugins | keys[]' ~/.claude/plugins/installed_plugins.json)
for plugin in $plugins; do
  echo "Updating ${plugin}..."
  claude plugin update "$plugin" 2>&1 || echo "  Failed to update ${plugin}"
done
echo ""
echo "Done! Restart Claude Code to apply updates."
