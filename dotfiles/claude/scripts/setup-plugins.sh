#!/usr/bin/env bash
# Setup Claude Code plugins: symlinks config files and installs missing plugins
#
# Usage: install-plugins.sh <claude-binary> <dotfiles-claude-dir>
#
# Creates symlinks for plugin config and installs only plugins
# not already present in ~/.claude/plugins/cache/

set -euo pipefail

CLAUDE_BIN="${1:?Usage: install-plugins.sh <claude-binary> <dotfiles-claude-dir>}"
DOTFILES_CLAUDE="${2:?Usage: install-plugins.sh <claude-binary> <dotfiles-claude-dir>}"

PLUGINS_DIR="${HOME}/.claude/plugins"
CACHE_DIR="${PLUGINS_DIR}/cache"
PLUGINS_JSON="${DOTFILES_CLAUDE}/plugins/installed_plugins.json"

# Setup plugin config symlinks
mkdir -p "$PLUGINS_DIR"
ln -sf "${DOTFILES_CLAUDE}/plugins/known_marketplaces.json" "${PLUGINS_DIR}/known_marketplaces.json"
ln -sf "${DOTFILES_CLAUDE}/plugins/installed_plugins.json" "${PLUGINS_DIR}/installed_plugins.json"

# Install plugins not already cached
plugins=$(jq -r '.plugins | keys[]' "$PLUGINS_JSON")

for plugin in $plugins; do
  # Parse plugin name and marketplace from "name@marketplace" format
  name="${plugin%@*}"
  marketplace="${plugin#*@}"
  cache_path="${CACHE_DIR}/${marketplace}/${name}"

  if [[ -d "$cache_path" ]]; then
    echo "Skipping ${plugin} (already cached)"
  else
    echo "Installing ${plugin}..."
    "$CLAUDE_BIN" plugin install "$plugin" --scope user 2>/dev/null || true
  fi
done
