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
    sandbox_workspace_write.network_access = true;
    model_context_window = 1000000;
    model_auto_compact_token_limit = 900000;
    model_reasoning_effort = "medium";
    model_reasoning_summary = "concise";
    hide_agent_reasoning = true;
    model_verbosity = "low";
    # Built-in web search is off; web access goes through the MCP servers (ai-sauce CORE.md "Web Access").
    web_search = "disabled";
    file_opener = "cursor";

    features = {
      network_proxy = {
        enabled = true;
        domains = lib.genAttrs (import ../agent-network-domains.nix) (_: "allow");
      };
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
      memories = false;
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
  home.file.".codex/AGENTS.md".text =
    config.ai.instructions + builtins.readFile "${ai}/pstack/for-codex.md";
  home.file.".codex/agents".source = "${ai}/agents/codex";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/codex.rules";

  # Same poteto-mode hook as Claude Code. Codex trusts a hook by the hash of its
  # definition, so the command is a stable path and not the store path, which
  # changes with every ai-sauce update. Trust it once through /hooks.
  home.file.".codex/hooks/pstack-mode".source = config.ai.pstackModeHook;
  home.file.".codex/hooks.json".text = builtins.toJSON {
    hooks.UserPromptSubmit = [
      {
        hooks = [
          {
            type = "command";
            command = "\"$HOME/.codex/hooks/pstack-mode\"";
            timeout = 5;
          }
        ];
      }
    ];
  };

  # Merge ~/.codex/config.toml at activation time so trusted projects can be
  # discovered dynamically without deleting Codex-managed plugin/app state.
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${codexConfigScript}" "${codexBaseConfig}" "${config.mcp.secretsFile}" "${pkgs.yq-go}/bin/yq"
  '';
}
