{
  config,
  pkgs,
  lib,
  ...
}:

let
  # MCP Server definitions - Single Source of Truth
  mcpServerDefs = {
    filesystem = {
      command = "npx";
      args = [ "-y" "@anthropic-ai/mcp-filesystem" ];
    };
    git = {
      command = "uvx";
      args = [ "mcp-server-git" ];
    };
    context7 = {
      command = "npx";
      args = [ "-y" "@upstash/context7-mcp" ];
    };
    github = {
      command = "npx";
      args = [ "-y" "@modelcontextprotocol/server-github" ];
    };
    playwright = {
      command = "npx";
      args = [ "-y" "@anthropic-ai/mcp-playwright" ];
    };
    "ast-grep" = {
      command = "npx";
      args = [ "-y" "@anthropic-ai/mcp-ast-grep" ];
    };
  };

  # Convert to CLI format
  cliMcpServers = builtins.mapAttrs (name: def: {
    command = def.command;
    args = def.args;
  } // (if def ? env then { env = def.env; } else {})) mcpServerDefs;

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
