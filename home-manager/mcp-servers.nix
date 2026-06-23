# MCP Server configuration - Single Source of Truth
# Other modules (claude-code.nix, gemini.nix, codex.nix) import and format as needed
{
  lib,
  pkgs,
  type,
  ...
}:

let
  homeAssistantMcpUrl = "http://homeassistant.internal:8123/api/mcp";
  homeAssistantKeychainService = "homeassistant-mcp-token";

  sharedMcpServers = {
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

  personalMcpServers = {
    homeassistant = {
      command = "${pkgs.bash}/bin/bash";
      args = [
        "-lc"
        ''
          homeassistant_token="''${HOMEASSISTANT_TOKEN:-}"

          if [ -z "$homeassistant_token" ]; then
            keychain_service="''${HOMEASSISTANT_KEYCHAIN_SERVICE:-${homeAssistantKeychainService}}"
            keychain_account="''${HOMEASSISTANT_KEYCHAIN_ACCOUNT:-$USER}"
            homeassistant_token="$(/usr/bin/security find-generic-password \
              -s "$keychain_service" \
              -a "$keychain_account" \
              -w 2>/dev/null || true)"
          fi

          if [ -z "$homeassistant_token" ]; then
            echo "Home Assistant MCP token not found in HOMEASSISTANT_TOKEN or macOS Keychain service $keychain_service" >&2
            exit 1
          fi

          API_ACCESS_TOKEN="$homeassistant_token" exec ${pkgs.mcp-proxy}/bin/mcp-proxy \
            --transport=streamablehttp \
            --stateless \
            "${homeAssistantMcpUrl}"
        ''
      ];
    };
  };
in

{
  options.mcp.servers = lib.mkOption {
    type = lib.types.attrs;
    description = "MCP server definitions shared across AI tools";
    default = sharedMcpServers // lib.optionalAttrs (type == "personal") personalMcpServers;
  };
}
