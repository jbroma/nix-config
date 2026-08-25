# MCP Server configuration - Single Source of Truth
# Other modules (claude-code.nix, codex.nix, cursor.nix) import and format as needed
{
  lib,
  pkgs,
  type,
  ...
}:

let
  # Hosted servers speak HTTP directly (the clients handle reconnects and 5xx).
  # Their API keys live in the macOS Keychain (service = <service>, account =
  # $USER) and are injected into the Claude Code, Codex, and Cursor configs at
  # activation from `mcp.secrets`.
  sharedMcpServers = {
    # Web access (ai-sauce CORE.md "Web Access" says which tool does what)
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
    };
    exa = {
      type = "http";
      url = "https://mcp.exa.ai/mcp?tools=web_search_exa,web_fetch_exa,web_search_advanced_exa";
    };
    firecrawl = {
      type = "http";
      url = "https://mcp.firecrawl.dev/v2/mcp";
    };
    grep = {
      type = "http";
      url = "https://mcp.grep.app";
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

  personalMcpServers = {
    homeassistant = {
      type = "http";
      url = "http://homeassistant.internal:8123/api/mcp";
    };
  };

  bearer = service: {
    inherit service;
    header = "Authorization";
    prefix = "Bearer ";
  };
  sharedSecrets = {
    context7 = bearer "context7-api-key";
    exa = {
      service = "exa-api-key";
      header = "x-api-key";
      prefix = "";
    };
    firecrawl = bearer "firecrawl-api-key";
  };
  personalSecrets = {
    homeassistant = bearer "homeassistant-mcp-token";
  };

  personal = type == "personal";
  servers = sharedMcpServers // lib.optionalAttrs personal personalMcpServers;
  secrets = sharedSecrets // lib.optionalAttrs personal personalSecrets;

  # `keychain-mcp sync` copies these 1Password fields into the Keychain services above.
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
in

{
  options.mcp.servers = lib.mkOption {
    type = lib.types.attrs;
    description = "MCP server definitions shared across AI tools";
    default = servers;
  };

  options.mcp.secrets = lib.mkOption {
    type = lib.types.attrs;
    description = "Keychain-backed HTTP headers per server: { <server> = { service; header; prefix; }; }";
    default = secrets;
  };

  options.mcp.secretsFile = lib.mkOption {
    type = lib.types.path;
    description = "TSV of <server> <header> <keychain service> <prefix>, consumed by the activation scripts (prefix last: it may be empty)";
    default = pkgs.writeText "mcp-secrets.tsv" (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: s: "${name}\t${s.header}\t${s.service}\t${s.prefix}") secrets
      )
    );
  };

  config.home.packages = [ keychainMcp ];

  # Warn (never prompt) when a configured API key is missing from the Keychain.
  config.home.activation.checkMcpKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    missing=""
    for service in ${lib.escapeShellArgs (map (s: s.service) (lib.attrValues secrets))}; do
      /usr/bin/security find-generic-password -s "$service" -a "$USER" >/dev/null 2>&1 || missing="$missing $service"
    done
    if [ -n "$missing" ]; then
      warnEcho "Keychain is missing MCP API keys:$missing"
      warnEcho "Run: keychain-mcp sync, then darwin-rebuild switch again to inject them"
    fi
  '';
}
