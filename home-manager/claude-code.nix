{
  config,
  pkgs,
  lib,
  ...
}:

let
  # MCP Server definitions - Single Source of Truth
  mcpServerDefs = {
    context7 = {
      command = "npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
    };
    chrome-devtools = {
      command = "npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
      ];
    };
  };

  # Convert to CLI format
  cliMcpServers = builtins.mapAttrs (
    name: def:
    {
      command = def.command;
      args = def.args;
    }
    // (if def ? env then { env = def.env; } else { })
  ) mcpServerDefs;

  cliConfigJson = builtins.toJSON cliMcpServers;
in
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
  };

  # Generate MCP servers config (used by integration.nix symlinks)
  xdg.configFile."claude/mcp-servers.json".text = cliConfigJson;
}
