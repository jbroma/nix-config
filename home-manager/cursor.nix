{
  pkgs,
  lib,
  ai,
  config,
  ...
}:
let
  cursorSettingsPath = builtins.path {
    path = ../dotfiles/vscode/settings.json;
    name = "source";
  };
  cursorSettingsJson = builtins.fromJSON (builtins.readFile cursorSettingsPath);

  managedCursorSettings = cursorSettingsJson // {
    "nix.serverPath" = "${pkgs.nil}/bin/nil";
    "nix.enableLanguageServer" = true;
    "nix.serverSettings" = {
      "nil" = {
        "formatting" = {
          "command" = [ "${pkgs.nixfmt}/bin/nixfmt" ];
        };
      };
    };
    "[nix]" = {
      "editor.defaultFormatter" = "jnoortheen.nix-ide";
    };
    # Native agent-finished chime (plays when the window is not focused).
    "cursor.composer.shouldChimeAfterChatFinishes" = true;
  };

  managedCursorSettingsFile = pkgs.writeText "cursor-managed-settings.json" (
    builtins.toJSON managedCursorSettings
  );
  # Keyless server list; Keychain-backed headers are injected at activation (cursorMcp below).
  # Cursor documents `type` only for stdio servers; remote ones are `{ url, headers }`.
  cursorMcpServers = lib.mapAttrs (
    _: server:
    if server ? url then builtins.removeAttrs server [ "type" ] else server // { type = "stdio"; }
  ) config.mcp.servers;
  cursorMcpConfigFile = pkgs.writeText "cursor-mcp.json" (
    builtins.toJSON {
      mcpServers = cursorMcpServers;
    }
  );
  cursorAgentSources = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) (
    builtins.readDir "${ai}/agents/codex"
  );
  cursorAgentFiles = lib.mapAttrs' (
    filename: _:
    let
      agentName = lib.removeSuffix ".toml" filename;
      agent = builtins.fromTOML (builtins.readFile "${ai}/agents/codex/${filename}");
      readonly = (agent.sandbox_mode or "") == "read-only";
    in
    {
      name = ".cursor/agents/${agentName}.md";
      value = {
        force = true;
        text = ''
          ---
          name: ${builtins.toJSON (agent.name or agentName)}
          description: ${builtins.toJSON (agent.description or "")}
          model: inherit
          readonly: ${if readonly then "true" else "false"}
          ---

          ${agent.developer_instructions or ""}
        '';
      };
    }
  ) cursorAgentSources;

  cursorExtensions =
    (with pkgs.vscode-marketplace; [
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      expo.vscode-expo-tools
      jnoortheen.nix-ide
      rust-lang.rust-analyzer
      flowtype.flow-for-vscode
      mhutchie.git-graph
      waderyan.gitblame
      github.github-vscode-theme
      yoavbls.pretty-ts-errors
      pkief.material-icon-theme
      msjsdiag.vscode-react-native
      ms-python.flake8
      ms-python.python
      redhat.vscode-yaml
      redhat.vscode-xml
      mk12.better-git-line-blame
      tombi-toml.tombi
      typescriptteam.native-preview
      vitest.explorer
    ])
    ++ (with pkgs.vscode-extensions; [
      biomejs.biome
      vadimcn.vscode-lldb
      unifiedjs.vscode-mdx
    ]);

  extensionLinks = builtins.concatMap (
    ext:
    let
      subDir = "share/vscode/extensions";
      extensionIds =
        if ext ? vscodeExtUniqueId then
          [ ext.vscodeExtUniqueId ]
        else
          builtins.attrNames (builtins.readDir "${ext}/${subDir}");
    in
    map (extensionId: {
      name = ".cursor/extensions/${extensionId}";
      value = {
        source = "${ext}/${subDir}/${extensionId}";
      };
    }) extensionIds
  ) cursorExtensions;
in
{
  # Cursor is kept on its own copies (skills, agents); the IDE toggle
  # "Include third-party Plugins, Skills, and other configs" stays off so it
  # never reads ~/.claude or ~/.codex. Global rules come from a local Cursor
  # plugin (the documented file-based route: ~/.cursor/plugins/local/<name>
  # with .cursor-plugin/plugin.json and rules/*.mdc); User Rules in the
  # Settings UI are account-synced text and are not managed here.
  home.file = {
    ".cursor/skills".source = "${ai}/skills";
    ".cursor/plugins/local/ai-sauce/.cursor-plugin/plugin.json".text = builtins.toJSON {
      name = "ai-sauce";
      description = "Personal rules from ai-sauce CORE.md";
    };
    ".cursor/plugins/local/ai-sauce/rules/core.mdc".text = ''
      ---
      description: Shared personal instructions from ai-sauce CORE.md
      alwaysApply: true
      ---

      ${config.ai.instructions}
    '';
  }
  // cursorAgentFiles
  // builtins.listToAttrs extensionLinks;

  # MCP servers with Keychain-backed headers (same merge as ~/.claude.json).
  home.activation.cursorMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.cursor"
    run ${../scripts/merge-mcp-servers.sh} \
      "$HOME/.cursor/mcp.json" \
      "${cursorMcpConfigFile}" \
      "${config.mcp.secretsFile}" \
      "${pkgs.jq}/bin/jq"
  '';

  # Warn if a Cursor update turned third-party (Claude/Codex) config loading back on.
  home.activation.checkCursorThirdParty = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    db="$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    if [ -f "$db" ]; then
      enabled="$(/usr/bin/sqlite3 -readonly "file:''${db// /%20}?immutable=1" \
        "select value from ItemTable where key = 'cursor/thirdPartyExtensibilityEnabled';" 2>/dev/null || true)"
      if [ "$enabled" != "false" ]; then
        warnEcho "Cursor third-party config loading is on: it will read ~/.claude and ~/.codex."
        warnEcho "Turn off Cursor Settings > Rules, Skills, Subagents > Include third-party Plugins, Skills, and other configs"
      fi
    fi
  '';

  # Keep Cursor settings mutable while applying Nix-managed settings on switch.
  home.activation.cursorSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${../scripts/merge-cursor-settings.sh} \
      "$HOME/Library/Application Support/Cursor/User/settings.json" \
      "${managedCursorSettingsFile}" \
      "${pkgs.jq}/bin/jq"
  '';
}
