#!/usr/bin/env bash
# keychain-mcp: on-demand macOS Keychain chores for the MCP servers declared in
# home-manager/mcp-servers.nix, which also sets the configuration:
#   KEYCHAIN_MCP_KEYS       lines of "<service>=<op://vault/item/field>"
#   KEYCHAIN_MCP_APP_ITEMS  lines of "<service>=<team id>"
#
# Commands:
#   status  list the configured Keychain items that exist (service, account)
#   sync    copy API keys from 1Password into the login Keychain so that
#           /usr/bin/security (used by the MCP wrappers) reads them silently
#   repin   pin the desktop apps' own items to the vendor team id; macOS pins
#           "Always Allow" to one build hash, so every app update re-prompts
set -euo pipefail

keychain="$HOME/Library/Keychains/login.keychain-db"

# Emit "service<TAB>account" for items whose service matches $1 exactly.
# (Attribute dump only: `dump-keychain -a` would add partition lists but walks
# every item's ACL through securityd and takes ages.)
items() {
  security dump-keychain "$keychain" 2>/dev/null </dev/null | awk -v want="$1" '
    /^keychain:/ { acct = "" }
    /"acct"<blob>=/ { match($0, /"acct"<blob>="[^"]*"/); acct = substr($0, RSTART + 14, RLENGTH - 15) }
    /"svce"<blob>=/ {
      match($0, /"svce"<blob>="[^"]*"/)
      if (substr($0, RSTART + 14, RLENGTH - 15) == want) print want "\t" acct
    }
  '
}

# Split "key=value" config lines into two arrays: names[] and values[].
parse() {
  names=()
  values=()
  local line
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      names+=("${line%%=*}")
      values+=("${line#*=}")
    fi
  done <<< "$1"
}

status() {
  {
    printf 'SERVICE\tACCOUNT\n'
    parse "$KEYCHAIN_MCP_KEYS"$'\n'"$KEYCHAIN_MCP_APP_ITEMS"
    for service in "${names[@]}"; do
      items "$service"
    done
  } | column -t -s $'\t'
}

sync() {
  command -v op >/dev/null || { echo "1Password CLI (op) not found in PATH" >&2; exit 1; }
  parse "$KEYCHAIN_MCP_KEYS"
  for i in "${!names[@]}"; do
    key="$(op read "${values[$i]}")"
    # -T grants /usr/bin/security; -U replaces an existing item (partition resets to apple-tool:, which is what we want).
    security add-generic-password -a "$USER" -s "${names[$i]}" -w "$key" -T /usr/bin/security -U
    echo "synced  ${names[$i]}"
  done
}

repin() {
  read -rsp "Login password (required to change Keychain ACLs): " password
  echo
  parse "$KEYCHAIN_MCP_APP_ITEMS"
  for i in "${!names[@]}"; do
    teamid="${values[$i]}"
    while IFS=$'\t' read -r svc acct; do
      security set-generic-password-partition-list \
        -S "apple-tool:,apple:,teamid:$teamid" -s "$svc" -a "$acct" -k "$password" </dev/null >/dev/null
      echo "pinned  $svc ($acct)"
    done < <(items "${names[$i]}")
  done
}

case "${1:-}" in
  status) status ;;
  sync) sync ;;
  repin) repin ;;
  *) echo "usage: keychain-mcp status|sync|repin" >&2; exit 2 ;;
esac
