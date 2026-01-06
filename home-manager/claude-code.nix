{
  pkgs,
  ai,
  ...
}:

let
  hookDefinitions = builtins.fromJSON (builtins.readFile "${ai}/hooks/definitions.json");
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
