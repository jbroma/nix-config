{
  pkgs,
  ...
}:

{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    agentsDir = ~/.cc/agents;
    commandsDir = ~/.cc/commands;
    hooksDir = ~/.cc/hooks;
    rulesDir = ~/.cc/rules;
    skillsDir = ~/.cc/skills;
  };
}
