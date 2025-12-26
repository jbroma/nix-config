{ config, lib, ... }:

let
  # Use absolute path to avoid nix flake git tracking issues
  aiDir = "${config.home.homeDirectory}/.nix/ai";
in
{
  # Claude Code symlinks
  home.file.".claude/CLAUDE.md".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/AGENTS.md";
  home.file.".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/commands";
  home.file.".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/skills";
  home.file.".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/agents";
  home.file.".claude/rules".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/rules";
  home.file.".claude/memory".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/memory";
  home.file.".claude/hooks".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/hooks";

  # Gemini CLI symlinks
  home.file.".gemini/GEMINI.md".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/AGENTS.md";
  home.file.".gemini/rules".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/rules";
  home.file.".gemini/mcp-servers.json".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/claude/mcp-servers.json";

  # Antigravity symlinks
  home.file.".gemini/antigravity/mcp_config.json".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/claude/mcp-servers.json";

  # Cursor symlink
  home.file.".cursorrules".source = config.lib.file.mkOutOfStoreSymlink "${aiDir}/AGENTS.md";
}
