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
  integrationConfig = builtins.fromJSON (builtins.readFile "${ai}/integrations/plugins.json");
  codexIntegrations = integrationConfig.codex;
  codexMarketplaces =
    lib.mapAttrs (
      _: marketplace: builtins.removeAttrs marketplace [ "add" ]
    ) codexIntegrations.marketplaces
    // {
      openai-bundled = {
        source_type = "local";
        source = "/Applications/ChatGPT.app/Contents/Resources/plugins/openai-bundled";
      };
    };
  codexPlugins = lib.mapAttrs (_: plugin: {
    enabled = plugin.enabled or false;
  }) codexIntegrations.plugins;
  installPlugins = builtins.attrNames (
    lib.filterAttrs (
      _: plugin: (plugin.enabled or false) && (plugin.install or true)
    ) codexIntegrations.plugins
  );
  installPluginCommands = lib.concatStringsSep "\n" (
    map (plugin: ''
      if ${pkgs.codex-cli}/bin/codex plugin list --json | ${pkgs.jq}/bin/jq -e --arg plugin ${lib.escapeShellArg plugin} '.installed[]? | select(.pluginId == $plugin)' >/dev/null; then
        echo "Skipping ${plugin} (already installed)"
      else
        run ${pkgs.codex-cli}/bin/codex plugin add ${lib.escapeShellArg plugin} >/dev/null || \
          echo "warning: failed to install Codex plugin: ${plugin}" >&2
      fi
    '') installPlugins
  );
  codeFontFamily = ''"Hack Nerd Font Mono", "FiraCode Nerd Font Mono", ui-monospace, "SFMono-Regular", Menlo, Monaco, Consolas, monospace'';
  codexSettings = {
    model = "gpt-5.5";
    personality = "pragmatic";
    approval_policy = "on-request";
    approvals_reviewer = "auto_review";
    sandbox_mode = "workspace-write";
    model_reasoning_effort = "high";
    model_reasoning_summary = "concise";
    model_verbosity = "low";
    # Built-in web search is off; web access goes through the exa/firecrawl/context7
    # MCP servers (ai-sauce skills/web-research).
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
    marketplaces = codexMarketplaces;
    plugins = codexPlugins;
  };
  codexBaseConfig = tomlFormat.generate "config.toml" codexSettings;
  codexConfigScript = ../scripts/generate-codex-config.sh;
in
{
  home.sessionVariables = {
    CODEX_HOME = "$HOME/.codex";
  };

  # Symlinks from ai submodule
  home.file.".codex/AGENTS.md".text = config.ai.instructions;
  home.file.".codex/agents".source = "${ai}/agents/codex";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/codex.rules";

  # Merge ~/.codex/config.toml at activation time so trusted projects can be
  # discovered dynamically without deleting Codex-managed plugin/app state.
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${codexConfigScript}" "${codexBaseConfig}" "${config.mcp.secretsFile}" "${pkgs.yq-go}/bin/yq"
  '';

  home.activation.codexPlugins = lib.hm.dag.entryAfter [ "codexConfig" ] ''
    mkdir -p \
      "${config.home.homeDirectory}/.codex/plugins/.marketplace-plugin-source-staging" \
      "${config.home.homeDirectory}/.codex/plugins/.remote-plugin-install-staging"
    ${installPluginCommands}
  '';
}
