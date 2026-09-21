#!/usr/bin/env bash
# Refresh Claude Code marketplaces and update user-installed plugins.

set -euo pipefail

echo "=== Updating marketplaces ==="
claude plugin marketplace update

echo ""
echo "=== Updating plugins ==="
plugins=$(jq -r '.plugins | keys[]' ~/.claude/plugins/installed_plugins.json)
failed_plugins=()
for plugin in $plugins; do
  echo "Updating ${plugin}..."
  if ! claude plugin update "$plugin"; then
    failed_plugins+=("$plugin")
  fi
done
if ((${#failed_plugins[@]} > 0)); then
  printf '\nFailed to update:\n' >&2
  printf '  %s\n' "${failed_plugins[@]}" >&2
  exit 1
fi
echo ""
echo "Done! Restart Claude Code to apply updates."
