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
  codexHooksDir = "${config.home.homeDirectory}/.codex/hooks";
  codexNotifyScript = "${codexHooksDir}/on-codex-notify.sh";
  codexMcpServers = lib.mapAttrs (
    _: server: lib.filterAttrs (k: _: k != "type") server
  ) config.mcp.servers;
  codexSettings = {
    model = "gpt-5.3-codex";
    model_personality = "pragmatic";
    approval_policy = "on-request";
    sandbox_mode = "workspace-write";
    model_reasoning_effort = "xhigh";
    model_reasoning_summary = "concise";
    model_verbosity = "medium";
    web_search = "cached";
    file_opener = "cursor";

    features = {
      shell_tool = true;
      shell_snapshot = true;
      unified_exec = true;
      multi_agent = true;
      request_rule = true;
      undo = true;
    };

    agents = {
      max_threads = 8;
    };

    profiles = {
      fast = {
        model_reasoning_effort = "low";
        model_verbosity = "low";
      };
      thorough = {
        model_reasoning_effort = "xhigh";
        web_search = "live";
      };
    };

    history.persistence = "save-all";
    notify = [ codexNotifyScript ];

    tui = {
      animations = true;
      show_tooltips = false;
      notifications = true;
    };

    mcp_servers = codexMcpServers;
  };
  codexBaseConfig = tomlFormat.generate "config.toml" codexSettings;
  codexConfigScript = ../scripts/generate-codex-config.sh;
in
{
  home.sessionVariables = {
    CODEX_HOME = "$HOME/.codex";
  };

  # Symlinks from ai submodule
  home.file.".codex/AGENTS.md".source = "${ai}/CORE.md";
  home.file.".codex/hooks".source = "${ai}/hooks";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/codex.rules";

  # Build ~/.codex/config.toml at activation time so trusted projects can be discovered dynamically.
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${codexConfigScript}" "${codexBaseConfig}"
  '';
}
