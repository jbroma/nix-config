# MCP Server definitions - Single Source of Truth
# Configure MCP servers for all AI tools here
{ ... }:

let
  servers = {
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
  };

  # JSON format for Gemini/Antigravity (same structure)
  serversJson = builtins.toJSON servers;
in
{
  # Claude Code MCP servers (uses --mcp-config wrapper)
  programs.claude-code.mcpServers = servers;

  # Gemini CLI MCP config
  home.file.".gemini/mcp-servers.json".text = serversJson;

  # Antigravity MCP config
  home.file.".gemini/antigravity/mcp_config.json".text = serversJson;
}
