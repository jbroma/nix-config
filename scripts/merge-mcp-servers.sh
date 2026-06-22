#!/usr/bin/env bash
# Merge MCP server configuration into ~/.claude.json
# Preserves Claude Code's application state (OAuth, preferences, stats)

set -euo pipefail

CLAUDE_JSON="$1"
MCP_CONFIG="$2"
JQ_BIN="$3"

if [ -f "$CLAUDE_JSON" ]; then
  # Replace the managed MCP server map while preserving Claude Code app state.
  "$JQ_BIN" --argjson mcp "$MCP_CONFIG" '.mcpServers = ($mcp.mcpServers // {})' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp"
  mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
  echo "MCP servers updated in $CLAUDE_JSON"
else
  # Create new file with just mcpServers
  echo "$MCP_CONFIG" > "$CLAUDE_JSON"
  echo "Created $CLAUDE_JSON with MCP servers"
fi
