# MCP Server definitions - Single Source of Truth
# Configure MCP servers for all AI tools here
{
  config,
  lib,
  pkgs,
  ...
}:

let
  servers = {
    context7 = {
      command = "npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
    };
    chrome-devtools = {
      command = "npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
      ];
    };
    shadcn = {
      command = "npx";
      args = [
        "-y"
        "shadcn@latest"
        "mcp"
      ];
    };
  };

  # JSON to merge into ~/.claude.json
  mcpConfig = {
    mcpServers = servers;
  };
  mcpConfigJson = builtins.toJSON mcpConfig;

  # Gemini uses flat server structure
  geminiConfig = servers;
in
{
  # Activation script: merge mcpServers into existing ~/.claude.json
  # This preserves Claude Code's application state (OAuth, preferences, stats)
  home.activation.setupMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${../scripts/merge-mcp-servers.sh} \
      "${config.home.homeDirectory}/.claude.json" \
      '${mcpConfigJson}' \
      "${pkgs.jq}/bin/jq"
  '';

  # Gemini CLI MCP config
  home.file.".gemini/mcp-servers.json".text = builtins.toJSON geminiConfig;

  # Antigravity MCP config
  home.file.".gemini/antigravity/mcp_config.json".text = builtins.toJSON geminiConfig;
}
