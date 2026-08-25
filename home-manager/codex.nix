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
  codexMcpServers = lib.mapAttrs (
    _: server: lib.filterAttrs (k: _: k != "type") server
  ) config.mcp.servers;
  codeFontFamily = ''"Hack Nerd Font Mono", "FiraCode Nerd Font Mono", ui-monospace, "SFMono-Regular", Menlo, Monaco, Consolas, monospace'';
  # Managed keys. `model` is deliberately absent: the app owns the model choice.
  codexSettings = {
    personality = "pragmatic";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    sandbox_mode = "workspace-write";
    model_reasoning_effort = "high";
    model_reasoning_summary = "concise";
    hide_agent_reasoning = true;
    model_verbosity = "low";
    # Built-in web search is off; web access goes through the MCP servers (ai-sauce CORE.md "Web Access").
    web_search = "disabled";
    file_opener = "cursor";

    features = {
      browser_use = true;
      browser_use_external = true;
      goals = true;
      in_app_browser = true;
      prevent_idle_sleep = true;
      shell_tool = true;
      shell_snapshot = true;
      unified_exec = true;
      computer_use = true;
      multi_agent = true;
    };

    agents = {
      max_concurrent_threads_per_session = 8;
    };

    history.persistence = "save-all";

    tui = {
      animations = true;
      show_tooltips = false;
      # Native turn-complete/approval notifications: OSC 9, which WezTerm shows as a macOS notification.
      notifications = true;
      notification_method = "osc9";
    };

    desktop = {
      appearanceDarkChromeTheme.fonts.code = codeFontFamily;
      appearanceLightChromeTheme.fonts.code = codeFontFamily;
    };

    mcp_servers = codexMcpServers;
  };
  codexBaseConfig = tomlFormat.generate "config.toml" codexSettings;
  codexConfigScript = ../scripts/generate-codex-config.sh;
in
{
  # Symlinks from ai submodule
  home.file.".codex/AGENTS.md".text = config.ai.instructions;
  home.file.".codex/agents".source = "${ai}/agents/codex";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/codex.rules";
  # Same PreToolUse Bash hook (dcg) as Claude Code; Codex reads this file since 0.125.
  home.file.".codex/hooks.json".text = builtins.toJSON { hooks = config.ai.hooks; };

  # Merge ~/.codex/config.toml at activation time so trusted projects can be
  # discovered dynamically without deleting Codex-managed plugin/app state.
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${codexConfigScript}" "${codexBaseConfig}" "${config.mcp.secretsFile}" "${pkgs.yq-go}/bin/yq"
  '';
}
