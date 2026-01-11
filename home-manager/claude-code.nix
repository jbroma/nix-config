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
in
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  # Claude Code symlinks
  home.file.".claude/CLAUDE.md".source = "${ai}/AGENTS.md";
  home.file.".claude/agents".source = "${ai}/agents";
  home.file.".claude/commands".source = "${ai}/commands";
  home.file.".claude/hooks".source = "${ai}/hooks";
  home.file.".claude/skills".source = "${ai}/skills";

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    settings = {
      # disalbe all mcp servers by default
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
