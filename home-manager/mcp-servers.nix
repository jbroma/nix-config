# MCP Server configuration - Single Source of Truth
# Other modules (claude-code.nix, gemini.nix, codex.nix) import and format as needed
{ lib, ... }:

{
  options.mcp.servers = lib.mkOption {
    type = lib.types.attrs;
    description = "MCP server definitions shared across AI tools";
    default = {
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
      shadcn = {
        command = "npx";
        args = [
          "-y"
          "shadcn@latest"
          "mcp"
        ];
      };

      # Hosted MCP servers (HTTP transport)
      grep = {
        type = "http";
        url = "https://mcp.grep.app";
      };
      exa = {
        type = "http";
        url = "https://mcp.exa.ai/mcp";
      };
    };
  };
}
