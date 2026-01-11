{
  pkgs,
  lib,
  ai,
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

  # Path to dotfiles in this repo (for mutable symlinks)
  dotfilesDir = "${config.home.homeDirectory}/.nix/dotfiles";

  # Read plugins from dotfile (single source of truth)
  installedPluginsJson = builtins.fromJSON (
    builtins.readFile ../dotfiles/claude/plugins/installed_plugins.json
  );
  plugins = builtins.attrNames installedPluginsJson.plugins;

  # Convert plugin list to { "plugin@marketplace" = true; } format
  enabledPlugins = lib.genAttrs plugins (_: true);

  claude = "${pkgs.claude-code}/bin/claude";

  pluginInstallScript = lib.concatMapStringsSep "\n" (plugin: ''
    run ${claude} plugin install ${plugin} --scope user 2>/dev/null || true
  '') plugins;
in
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  # Claude Code symlinks (read-only, from ai submodule)
  home.file.".claude/CLAUDE.md".source = "${ai}/AGENTS.md";
  home.file.".claude/agents".source = "${ai}/agents";
  home.file.".claude/commands".source = "${ai}/commands";
  home.file.".claude/hooks".source = "${ai}/hooks";
  home.file.".claude/skills".source = "${ai}/skills";

  # Plugin config: direct symlinks via activation (avoids nix store symlink chain)
  # This works around Claude Code only resolving one level of symlinks
  home.activation.setupClaudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.claude/plugins"

    run ln -sf "${dotfilesDir}/claude/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"
    run ln -sf "${dotfilesDir}/claude/plugins/installed_plugins.json" "$HOME/.claude/plugins/installed_plugins.json"

    # Install plugins
    ${pluginInstallScript}
  '';

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      # Default model - use Opus 4.5 for best quality
      model = "claude-opus-4-5";
      # Disable all mcp servers by default
      enableAllProjectMcpServers = false;
      # Enable plugins from dotfile (single source of truth)
      enabledPlugins = enabledPlugins;
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
