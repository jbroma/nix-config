#!/usr/bin/env bash
# Setup Claude Code plugins: symlinks config files and installs missing plugins
#
# Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path]
#
# Creates symlinks for plugin config and installs only plugins
# not already present in ~/.claude/plugins/cache/

set -euo pipefail

CLAUDE_BIN="${1:?Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path]}"
DOTFILES_CLAUDE="${2:?Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path]}"
LOCAL_MARKETPLACE="${3:-}"

PLUGINS_DIR="${HOME}/.claude/plugins"
CACHE_DIR="${PLUGINS_DIR}/cache"
PLUGINS_JSON="${DOTFILES_CLAUDE}/plugins/installed_plugins.json"
KNOWN_MARKETPLACES_TEMPLATE="${DOTFILES_CLAUDE}/plugins/known_marketplaces.json"
KNOWN_MARKETPLACES_PATH="${PLUGINS_DIR}/known_marketplaces.json"

# Setup plugin config symlinks
mkdir -p "$PLUGINS_DIR"
ln -sf "${DOTFILES_CLAUDE}/plugins/installed_plugins.json" "${PLUGINS_DIR}/installed_plugins.json"

# Claude mutates known marketplaces during updates, so keep it as local state.
if [[ ! -e "$KNOWN_MARKETPLACES_PATH" ]]; then
  cp "$KNOWN_MARKETPLACES_TEMPLATE" "$KNOWN_MARKETPLACES_PATH"
fi

# Add local marketplace if path provided
if [[ -n "$LOCAL_MARKETPLACE" && -d "$LOCAL_MARKETPLACE" ]]; then
  if "$CLAUDE_BIN" plugin marketplace list --json \
    | jq -e --arg path "$LOCAL_MARKETPLACE" 'any(.[]; .source == "directory" and .path == $path)' >/dev/null; then
    :
  elif ! "$CLAUDE_BIN" plugin marketplace add "$LOCAL_MARKETPLACE"; then
    echo "warning: failed to add local Claude plugin marketplace: $LOCAL_MARKETPLACE" >&2
  fi
fi

# Install plugins not already cached
failed_plugins=()

while IFS= read -r plugin; do
  # Parse plugin name and marketplace from "name@marketplace" format
  name="${plugin%@*}"
  marketplace="${plugin#*@}"
  cache_path="${CACHE_DIR}/${marketplace}/${name}"

  if [[ -d "$cache_path" ]]; then
    echo "Skipping ${plugin} (already cached)"
  else
    echo "Installing ${plugin}..."
    if ! "$CLAUDE_BIN" plugin install "$plugin" --scope user; then
      failed_plugins+=("$plugin")
    fi
  fi
done < <(jq -r '.plugins | keys[]' "$PLUGINS_JSON")

if ((${#failed_plugins[@]} > 0)); then
  echo "warning: failed to install Claude plugins:" >&2
  for plugin in "${failed_plugins[@]}"; do
    echo "  - ${plugin}" >&2
  done
fi
