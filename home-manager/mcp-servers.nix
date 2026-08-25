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

  # Hosted HTTP MCP server whose API key lives in the macOS Keychain
  # (service = <service>, account = $USER). Bridged over stdio with mcp-proxy so
  # Claude Code and Codex share one definition and the key never lands in a
  # config file or the Nix store. Without a key the server connects keyless
  # unless `required` is set.
  # Add a key: security add-generic-password -a "$USER" -s <service> -w '<key>' -U
  keychainHttpServer =
    {
      url,
      service,
      header ? "Authorization",
      prefix ? "Bearer ",
      required ? false,
    }:
    {
      command = "${pkgs.bash}/bin/bash";
      args = [
        "-c"
        ''
          key="$(/usr/bin/security find-generic-password -s ${service} -a "$USER" -w 2>/dev/null || true)"
          headers=()
          if [ -n "$key" ]; then
            headers=(--headers ${header} "${prefix}$key")
          elif ${lib.boolToString required}; then
            echo "Missing API key. Add it with: security add-generic-password -a \"$USER\" -s ${service} -w '<key>' -U" >&2
            exit 1
          fi
          exec ${pkgs.mcp-proxy}/bin/mcp-proxy --transport streamablehttp "''${headers[@]}" "${url}"
        ''
      ];
    };

  # `keychain-mcp sync` copies these 1Password fields into the Keychain services
  # used above.
  keychainKeys = {
    exa-api-key = "op://Personal/Exa/Personal API Key";
    firecrawl-api-key = "op://Personal/Firecrawl/Personal API Key";
    context7-api-key = "op://Personal/Context7/Personal API Key";
  };

  # Desktop apps whose own Keychain items macOS pins to a single build hash on
  # "Always Allow", so every app update re-prompts. `keychain-mcp repin` moves
  # them to the vendor's team id (OpenAI 2DC432GLL2, Anthropic Q6L2SF6YDW).
  appKeychainItems = {
    "Codex Safe Storage" = "2DC432GLL2";
    "Codex Storage Key" = "2DC432GLL2";
    "Codex MCP Credentials" = "2DC432GLL2";
    "Claude Safe Storage" = "Q6L2SF6YDW";
  };

  configLines = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") attrs);
  keychainMcp = pkgs.writeShellApplication {
    name = "keychain-mcp";
    runtimeEnv = {
      KEYCHAIN_MCP_KEYS = configLines keychainKeys;
      KEYCHAIN_MCP_APP_ITEMS = configLines appKeychainItems;
    };
    text = builtins.readFile ../scripts/keychain-mcp.sh;
  };

  sharedMcpServers = {
    # Web access (ai-sauce CORE.md "Web Access" says which tool does what)
    context7 = keychainHttpServer {
      url = "https://mcp.context7.com/mcp";
      service = "context7-api-key";
    };
    exa = keychainHttpServer {
      url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
      service = "exa-api-key";
      header = "x-api-key";
      prefix = "";
    };
    firecrawl = keychainHttpServer {
      url = "https://mcp.firecrawl.dev/v2/mcp";
      service = "firecrawl-api-key";
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

  config.home.packages = [ keychainMcp ];
}
