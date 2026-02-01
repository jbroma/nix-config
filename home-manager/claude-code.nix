{
  pkgs,
  lib,
  ai,
  utils,
  config,
  ...
}:

let
  hooksDir = "${config.home.homeDirectory}/.claude/hooks";
  hookDefinitionsRaw = builtins.readFile "${ai}/hooks/definitions.json";
  hookDefinitionsResolved =
    builtins.replaceStrings [ "$USER_HOOKS_DIR" ] [ hooksDir ]
      hookDefinitionsRaw;
  hookDefinitions = builtins.fromJSON hookDefinitionsResolved;

  # Read and parse permissions from ai submodule + add defaultMode for file edits
  permissionsJsonc = builtins.readFile "${ai}/permissions.jsonc";
  permissions = utils.fromJSONC permissionsJsonc // {
    defaultMode = "allowEdits";
  };

  # Path to dotfiles in this repo (for mutable symlinks)
  dotfilesDir = "${config.home.homeDirectory}/.nix/dotfiles";

  # Read plugins from dotfile (single source of truth)
  installedPluginsJson = builtins.fromJSON (
    builtins.readFile ../dotfiles/claude/plugins/installed_plugins.json
  );
  plugins = builtins.attrNames installedPluginsJson.plugins;

  # Convert plugin list to { "plugin@marketplace" = true; } format
  enabledPlugins = lib.genAttrs plugins (_: true) // {
    "claude-island@local-marketplace" = true;
  };

  # Local marketplace for custom plugins (symlinked to ~/.claude/plugins/local-marketplace)
  localMarketplacePath = "${config.home.homeDirectory}/.claude/plugins/local-marketplace";

  claude = "${pkgs.claude-code}/bin/claude";
  setupScript = "${dotfilesDir}/claude/scripts/setup-plugins.sh";
in
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    ENABLE_TOOL_SEARCH = "auto:5";
  };

  # Claude Code symlinks (read-only, from ai submodule)
  home.file.".claude/CLAUDE.md".source = "${ai}/AGENTS.md";
  home.file.".claude/agents".source = "${ai}/agents";
  home.file.".claude/commands".source = "${ai}/commands";
  home.file.".claude/hooks".source = "${ai}/hooks";
  home.file.".claude/plugins/local-marketplace".source = "${ai}/marketplace";
  home.file.".claude/skills".source = "${ai}/skills";

  # Binary symlink for ~/.local/bin (needed by claude code native install)
  home.file.".local/bin/claude".source = "${pkgs.claude-code}/bin/claude";

  # Plugin setup: symlinks config files and installs missing plugins
  # Uses direct symlinks (not nix store) since Claude Code only resolves one level
  home.activation.setupClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${lib.makeBinPath [ pkgs.jq ]}:$PATH" run ${setupScript} ${claude} ${dotfilesDir}/claude "${localMarketplacePath}"
  '';

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      # Default model - use Opus for best quality
      model = "opus";
      # Default permissions from ai submodule + allowEdits mode
      permissions = permissions;
      # Enable plugins from dotfile (single source of truth)
      enabledPlugins = enabledPlugins;
      # Local marketplace for custom plugins (e.g., claude-island)
      extraKnownMarketplaces = {
        "local-marketplace" = {
          source = {
            source = "file";
            path = "${localMarketplacePath}/.claude-plugin/marketplace.json";
          };
        };
      };
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
