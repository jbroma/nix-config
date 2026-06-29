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
  integrationConfig = builtins.fromJSON (builtins.readFile "${ai}/integrations/plugins.json");
  codexIntegrations = integrationConfig.codex;
  codexMarketplaces = lib.mapAttrs (
    _: marketplace: builtins.removeAttrs marketplace [ "add" ]
  ) codexIntegrations.marketplaces;
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
    model_reasoning_summary = "auto";
    model_verbosity = "low";
    web_search = "live";
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
      max_threads = 8;
    };

    history.persistence = "save-all";
    notify = [ codexNotifyScript ];

    tui = {
      animations = true;
      show_tooltips = false;
      notifications = true;
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
  home.file.".codex/AGENTS.md".source = "${ai}/CORE.md";
  home.file.".codex/agents".source = "${ai}/agents";
  home.file.".codex/hooks".source = "${ai}/hooks";
  home.file.".codex/skills".source = "${ai}/skills";
  home.file.".codex/rules/default.rules".source = "${ai}/rules/codex.rules";

  # Merge ~/.codex/config.toml at activation time so trusted projects can be
  # discovered dynamically without deleting Codex-managed plugin/app state.
  home.activation.codexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash "${codexConfigScript}" "${codexBaseConfig}" "${pkgs.yq-go}/bin/yq"
  '';

  home.activation.codexPlugins = lib.hm.dag.entryAfter [ "codexConfig" ] ''
    mkdir -p \
      "${config.home.homeDirectory}/.codex/plugins/.marketplace-plugin-source-staging" \
      "${config.home.homeDirectory}/.codex/plugins/.remote-plugin-install-staging"
    ${installPluginCommands}
  '';
}
