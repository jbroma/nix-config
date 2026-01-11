{
  pkgs,
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

  # Plugin config symlinks (mutable, tracked in this repo)
  # Changes made by Claude CLI will show up in git diff
  home.file.".claude/plugins/known_marketplaces.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/plugins/known_marketplaces.json";
  home.file.".claude/plugins/installed_plugins.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/claude/plugins/installed_plugins.json";

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      # Default model - use Opus 4.5 for best quality
      model = "claude-opus-4-5";

      # Disable automatic context compaction
      autoCompact = false;

      # Disable all mcp servers by default
      enableAllProjectMcpServers = false;

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
