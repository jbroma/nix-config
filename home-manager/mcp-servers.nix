# MCP Server configuration - Single Source of Truth
# Configures MCP servers for: Claude Code, Gemini, Codex
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

    # Hosted MCP servers (HTTP transport)
    grep = {
      type = "http";
      url = "https://mcp.grep.app";
    };
    exa = {
      type = "http";
      url = "https://mcp.exa.ai/mcp";
    };
  };

  # Claude Code: JSON format with mcpServers wrapper
  claudeConfig = {
    mcpServers = servers;
  };
  claudeConfigJson = builtins.toJSON claudeConfig;

  # Gemini: flat server structure
  geminiConfig = servers;

  # Codex: TOML format, mcp_servers key, no "type" field for HTTP servers
  tomlFormat = pkgs.formats.toml { };
  codexMcpServers = lib.mapAttrs (_: server: lib.filterAttrs (k: _: k != "type") server) servers;
  codexSettings = {
    model = "o3";
    approval_policy = "on-failure";
    sandbox_mode = "workspace-write";
    model_reasoning_effort = "medium";

    history = {
      persistence = "save-all";
    };

    tui = {
      animations = true;
    };

    mcp_servers = codexMcpServers;
  };
in
{
  # Claude Code: merge mcpServers into existing ~/.claude.json
  # Preserves Claude Code's application state (OAuth, preferences, stats)
  home.activation.setupMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${../scripts/merge-mcp-servers.sh} \
      "${config.home.homeDirectory}/.claude.json" \
      '${claudeConfigJson}' \
      "${pkgs.jq}/bin/jq"
  '';

  # Gemini CLI MCP config
  home.file.".gemini/mcp-servers.json".text = builtins.toJSON geminiConfig;

  # Antigravity MCP config
  home.file.".gemini/antigravity/mcp_config.json".text = builtins.toJSON geminiConfig;

  # Codex config (includes MCP servers)
  home.file.".codex/config.toml".source = tomlFormat.generate "config.toml" codexSettings;
}
