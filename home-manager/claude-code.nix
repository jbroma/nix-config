{
  pkgs,
  lib,
  ai,
  config,
  ...
}:

let
  # MCP servers: wrap in mcpServers key for Claude Code format
  mcpServersConfig = {
    mcpServers = config.mcp.servers;
  };
  mcpServersJson = builtins.toJSON mcpServersConfig;

  hooksDir = "${config.home.homeDirectory}/.claude/hooks";
  hookDefinitionsRaw = builtins.readFile "${ai}/hooks/definitions.json";
  hookDefinitionsResolved =
    builtins.replaceStrings [ "$USER_HOOKS_DIR" ] [ hooksDir ]
      hookDefinitionsRaw;
  hookDefinitions = builtins.fromJSON hookDefinitionsResolved;

  permissions = builtins.fromJSON (builtins.readFile "${ai}/rules/rules.json");

  # Path to dotfiles in this repo (for mutable symlinks)
  dotfilesDir = "${config.home.homeDirectory}/.nix/dotfiles";

  integrationConfig = builtins.fromJSON (builtins.readFile "${ai}/integrations/plugins.json");
  claudeIntegrations = integrationConfig.claude;

  # Read existing plugin state from dotfile seed, then add desired plugins from ai-sauce.
  installedPluginsJson = builtins.fromJSON (
    builtins.readFile ../dotfiles/claude/plugins/installed_plugins.json
  );
  desiredPlugins = builtins.attrNames (
    lib.filterAttrs (_: plugin: plugin.enabled or false) claudeIntegrations.plugins
  );
  installPlugins = builtins.attrNames (
    lib.filterAttrs (
      _: plugin: (plugin.enabled or false) && (plugin.install or true)
    ) claudeIntegrations.plugins
  );
  plugins = lib.unique ((builtins.attrNames installedPluginsJson.plugins) ++ desiredPlugins);

  # Convert plugin list to { "plugin@marketplace" = true; } format
  enabledPlugins = lib.genAttrs plugins (_: true);

  # AI Sauce marketplace for custom and imported plugins.
  aiSauceMarketplacePath = "${config.home.homeDirectory}/.claude/plugins/ai-sauce-marketplace";
  resolveClaudeMarketplace =
    marketplace:
    let
      source = marketplace.source;
    in
    if
      source.source == "directory" && (source ? path) && source.path == "$AI_SAUCE_CLAUDE_MARKETPLACE"
    then
      marketplace
      // {
        source = source // {
          path = aiSauceMarketplacePath;
        };
      }
    else
      marketplace;
  extraKnownMarketplaces = lib.mapAttrs (_: resolveClaudeMarketplace) claudeIntegrations.marketplaces;

  claude = "${pkgs.claude-code}/bin/claude";
  setupScript = "${dotfilesDir}/claude/scripts/setup-plugins.sh";
  githubMarketplaceCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: marketplace:
      let
        source = marketplace.source;
      in
      if source.source == "github" then
        ''
          run ${claude} plugin marketplace add ${lib.escapeShellArg source.repo} || \
            echo "warning: failed to add Claude marketplace: ${name}" >&2
        ''
      else
        ""
    ) claudeIntegrations.marketplaces
  );
  installPluginArgs = lib.concatMapStringsSep " " lib.escapeShellArg installPlugins;
in
{
  # Claude Code symlinks (read-only, from ai submodule)
  home.file.".claude/CLAUDE.md".source = "${ai}/CORE.md";
  home.file.".claude/hooks".source = "${ai}/hooks";
  home.file.".claude/plugins/ai-sauce-marketplace".source = "${ai}/marketplace";
  home.file.".claude/skills".source = "${ai}/skills";

  # Binary symlink for ~/.local/bin (needed by claude code native install)
  home.file.".local/bin/claude".source = "${pkgs.claude-code}/bin/claude";

  # MCP servers: merge into ~/.claude.json (preserves OAuth, preferences, stats)
  home.activation.setupMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${../scripts/merge-mcp-servers.sh} \
      "${config.home.homeDirectory}/.claude.json" \
      '${mcpServersJson}' \
      "${pkgs.jq}/bin/jq"
  '';

  # Plugin setup: seeds mutable plugin state and installs missing plugins.
  # Uses direct marketplace symlinks since Claude Code only resolves one level.
  home.activation.setupClaudePlugins = lib.hm.dag.entryAfter [ "setupMcpServers" ] ''
    ${githubMarketplaceCommands}
    PATH="${lib.makeBinPath [ pkgs.jq ]}:$PATH" run ${setupScript} ${claude} ${dotfilesDir}/claude "${aiSauceMarketplacePath}" ${installPluginArgs}
  '';

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      # Pin Opus with the 1M context window and require confirmation before switching on flagged requests.
      model = "opus[1m]";
      switchModelsOnFlag = false;
      # Keep extended thinking enabled.
      alwaysThinkingEnabled = true;
      # Claude-specific environment configuration belongs in settings.json.
      env = {
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        ENABLE_TOOL_SEARCH = "true";
        CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
      };
      attribution = {
        commit = "";
        pr = "";
      };
      # Permission rules from ai submodule.
      permissions = permissions;
      # Enabled plugins combine existing mutable plugin state with ai-sauce desired integrations.
      enabledPlugins = enabledPlugins;
      # Marketplaces are declared in ai-sauce/integrations/plugins.json.
      extraKnownMarketplaces = extraKnownMarketplaces;
      hooks = hookDefinitions;
      sandbox = {
        enabled = true;
        excludedCommands = [ "git" ];
        autoAllowBashIfSandboxed = true;
        network = {
          allowLocalBinding = true;
        };
      };
    };
  };
}
