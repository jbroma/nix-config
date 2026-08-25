#!/usr/bin/env bash
# Merge MCP server configuration into ~/.claude.json and inject Keychain-backed
# headers. Preserves Claude Code's application state (OAuth, preferences, stats).
# Usage: merge-mcp-servers.sh <claude.json> <mcp-servers.json> <mcp-secrets.tsv> <jq>

set -euo pipefail

CLAUDE_JSON="$1"
MCP_FILE="$2"
SECRETS_TSV="$3"
JQ_BIN="$4"
TMP="$CLAUDE_JSON.tmp"

if [ -f "$CLAUDE_JSON" ]; then
  # Replace the managed MCP server map while preserving Claude Code app state.
  "$JQ_BIN" --slurpfile mcp "$MCP_FILE" '.mcpServers = ($mcp[0].mcpServers // {})' "$CLAUDE_JSON" > "$TMP"
else
  cp "$MCP_FILE" "$TMP"
fi

# Keychain-backed headers: <server> <header> <keychain service> <prefix> (tab-separated, prefix may be empty).
while IFS=$'\t' read -r server header service prefix; do
  [ -n "$server" ] || continue
  key="$(/usr/bin/security find-generic-password -s "$service" -a "$USER" -w 2>/dev/null </dev/null || true)"
  [ -n "$key" ] || continue
  "$JQ_BIN" --arg s "$server" --arg h "$header" --arg v "$prefix$key" \
    'if .mcpServers[$s] then .mcpServers[$s].headers[$h] = $v else . end' "$TMP" > "$TMP.2"
  mv "$TMP.2" "$TMP"
done < "$SECRETS_TSV"

mv "$TMP" "$CLAUDE_JSON"
echo "MCP servers updated in $CLAUDE_JSON"
