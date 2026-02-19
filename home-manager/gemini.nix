{
  ai,
  config,
  ...
}:

let
  # MCP servers: flat structure for Gemini
  mcpServersJson = builtins.toJSON config.mcp.servers;
in
{
  # Gemini CLI symlinks
  home.file.".gemini/GEMINI.md".source = "${ai}/CORE.md";
  home.file.".gemini/rules".source = "${ai}/rules";

  # MCP server configs
  home.file.".gemini/mcp-servers.json".text = mcpServersJson;
  home.file.".gemini/antigravity/mcp_config.json".text = mcpServersJson;

  home.packages = [
    # pkgs.gemini-cli  # Uncomment when available in nixpkgs
  ];
}
