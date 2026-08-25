#!/usr/bin/env bash
# Merge MCP server configuration into ~/.claude.json
# Preserves Claude Code's application state (OAuth, preferences, stats)
# Usage: merge-mcp-servers.sh <claude.json> <mcp-servers.json> <jq>

set -euo pipefail

CLAUDE_JSON="$1"
MCP_FILE="$2"
JQ_BIN="$3"

if [ -f "$CLAUDE_JSON" ]; then
  # Replace the managed MCP server map while preserving Claude Code app state.
  "$JQ_BIN" --slurpfile mcp "$MCP_FILE" '.mcpServers = ($mcp[0].mcpServers // {})' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
  mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
  echo "MCP servers updated in $CLAUDE_JSON"
else
  # Create new file with just mcpServers
  cp "$MCP_FILE" "$CLAUDE_JSON"
  echo "Created $CLAUDE_JSON with MCP servers"
fi
