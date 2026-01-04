{ config, pkgs, ... }:

let
  # Use absolute path to avoid nix flake git tracking issues
  aiDir = "${config.home.homeDirectory}/.nix/ai";
in
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  # Claude Code symlinks
  home.file.".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/AGENTS.md";
  home.file.".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/agents";
  home.file.".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/commands";
  home.file.".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/skills";

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      # disalbe all mcp servers by default
      enableAllProjectMcpServers = false;
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
