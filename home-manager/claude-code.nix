{ pkgs, ... }:

{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

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
