{
  ai,
  lib,
  pkgs,
  config,
  ...
}:

let
  # Codex: TOML format, mcp_servers key, strip "type" field for HTTP servers
  tomlFormat = pkgs.formats.toml { };
  codexMcpServers = lib.mapAttrs (_: server: lib.filterAttrs (k: _: k != "type") server) config.mcp.servers;
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
  home.sessionVariables = {
    CODEX_HOME = "$HOME/.codex";
  };

  # Symlinks from ai submodule
  home.file.".codex/AGENTS.md".source = "${ai}/AGENTS.md";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/rules.toml";

  # Codex config (includes MCP servers)
  home.file.".codex/config.toml".source = tomlFormat.generate "config.toml" codexSettings;
}
