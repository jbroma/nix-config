#!/usr/bin/env bash
# Setup Claude Code plugins: seeds mutable plugin state and installs missing plugins
#
# Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path] [extra-plugin...]
#
# Seeds plugin config and installs only plugins not already registered with
# Claude Code.

set -euo pipefail

CLAUDE_BIN="${1:?Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path]}"
DOTFILES_CLAUDE="${2:?Usage: setup-plugins.sh <claude-binary> <dotfiles-claude-dir> [local-marketplace-path]}"
LOCAL_MARKETPLACE="${3:-}"
EXTRA_PLUGINS=("${@:4}")

PLUGINS_DIR="${HOME}/.claude/plugins"
PLUGINS_TEMPLATE="${DOTFILES_CLAUDE}/plugins/installed_plugins.json"
PLUGINS_JSON="${PLUGINS_DIR}/installed_plugins.json"
KNOWN_MARKETPLACES_TEMPLATE="${DOTFILES_CLAUDE}/plugins/known_marketplaces.json"
KNOWN_MARKETPLACES_PATH="${PLUGINS_DIR}/known_marketplaces.json"

# Seed mutable plugin state. Claude rewrites this file during installs/updates.
mkdir -p "$PLUGINS_DIR"
if [[ -L "$PLUGINS_JSON" ]]; then
  tmp="$(mktemp "${PLUGINS_JSON}.seed.XXXXXX")"
  cp "$PLUGINS_JSON" "$tmp"
  rm "$PLUGINS_JSON"
  mv "$tmp" "$PLUGINS_JSON"
elif [[ ! -e "$PLUGINS_JSON" ]]; then
  cp "$PLUGINS_TEMPLATE" "$PLUGINS_JSON"
fi

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

with_writable_claude_settings() {
  local settings="${HOME}/.claude/settings.json"
  local backup="${settings}.managed-link"
  local tmp status

  [[ -L "$settings" ]] || return 1
  [[ ! -e "$backup" ]] || return 1

  tmp="$(mktemp "${settings}.writable.XXXXXX")"
  cp "$settings" "$tmp"

  restore_claude_settings() {
    rm -f "$settings"
    mv "$backup" "$settings"
  }

  mv "$settings" "$backup"
  mv "$tmp" "$settings"
  trap restore_claude_settings RETURN

  status=0
  "$@" || status=$?

  restore_claude_settings
  trap - RETURN
  return "$status"
}

install_plugin() {
  local plugin="$1"
  local settings="${HOME}/.claude/settings.json"

  if [[ -L "$settings" ]]; then
    with_writable_claude_settings "$CLAUDE_BIN" plugin install "$plugin" --scope user
    return $?
  fi

  if "$CLAUDE_BIN" plugin install "$plugin" --scope user; then
    return 0
  fi

  echo "Retrying ${plugin} with temporary writable Claude settings..."
  with_writable_claude_settings "$CLAUDE_BIN" plugin install "$plugin" --scope user
}

is_plugin_installed() {
  local plugin="$1"
  local install_path

  install_path="$(
    "$CLAUDE_BIN" plugin list --json 2>/dev/null \
      | jq -r --arg plugin "$plugin" '.[] | select(.id == $plugin) | .installPath // empty' \
      | sed -n '1p'
  )" || install_path=""

  [[ -n "$install_path" && -d "$install_path" ]]
}

# Install plugins not already registered
failed_plugins=()

while IFS= read -r plugin; do
  [[ -n "$plugin" ]] || continue

  if is_plugin_installed "$plugin"; then
    echo "Skipping ${plugin} (already installed)"
  else
    echo "Installing ${plugin}..."
    if ! install_plugin "$plugin"; then
      failed_plugins+=("$plugin")
    fi
  fi
done < <(
  {
    jq -r '.plugins | keys[]' "$PLUGINS_JSON"
    printf '%s\n' "${EXTRA_PLUGINS[@]}"
  } | sort -u
)

if ((${#failed_plugins[@]} > 0)); then
  echo "warning: failed to install Claude plugins:" >&2
  for plugin in "${failed_plugins[@]}"; do
    echo "  - ${plugin}" >&2
  done
fi
