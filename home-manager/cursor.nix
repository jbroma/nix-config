{
  pkgs,
  lib,
  ai,
  config,
  ...
}:
let
  cursorSettingsJson = builtins.fromJSON (builtins.readFile ../dotfiles/vscode/settings.json);

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
  # Permission rules come from the same rules.json Claude Code uses, so
  # rules.yaml in ai-sauce stays the one source. Cursor's allowlists take
  # "git status" and "exa:web_fetch_exa" where Claude takes "Bash(git status:*)"
  # and "mcp__exa__web_fetch_exa".
  rules = builtins.fromJSON (builtins.readFile "${ai}/rules/rules.json");
  matching = regex: list: lib.filter (m: m != null) (map (builtins.match regex) list);
  bashRule = "Bash\\((.*):\\*\\)";
  cursorPermissions = {
    terminalAllowlist = map lib.head (matching bashRule rules.allow);
    mcpAllowlist = map (m: "${lib.head m}:${lib.last m}") (matching "mcp__(.+)__(.+)" rules.allow);
  };

  # Cursor has allowlists but no deny list, so hooks enforce the deny rules. Each
  # hook is one jq filter that prints a decision on a match and nothing otherwise,
  # which leaves the decision to the allowlist.
  readRule = "Read\\((.*)\\)";
  denyHook =
    name: field: permission: flags: regex:
    "${pkgs.jq}/bin/jq -c -f ${pkgs.writeText "cursor-deny-${name}.jq" ''
      .${field} // "" | select(test(${builtins.toJSON regex}; "${flags}"))
      | "Matches an ai-sauce deny rule: \(.)" as $message
      | {permission: "${permission}", user_message: $message, agent_message: $message}
    ''}";
  # A denied command at the start of a line or after a shell separator. It asks
  # instead of denying, because the same text inside a quoted string also matches.
  deniedCommands = map (m: lib.escapeRegex (lib.head m)) (matching bashRule rules.deny);
  shellHook =
    denyHook "shell" "command" "ask" ""
      "(^|[;&|(`\n])\\s*(${lib.concatStringsSep "|" deniedCommands})(\\s|$)";
  # Claude's globs as regexes, matched without case because APFS ignores it.
  deniedReads = map (
    m:
    "^${
      builtins.replaceStrings
        [
          "\\*\\*"
          "\\*"
          "~/"
        ]
        [
          ".*"
          "[^/]*"
          "${lib.escapeRegex config.home.homeDirectory}/"
        ]
        (lib.escapeRegex (lib.head m))
    }$"
  ) (matching readRule rules.deny);
  readHook = denyHook "read" "file_path" "deny" "i" (lib.concatStringsSep "|" deniedReads);
  # Bare tool names such as WebFetch have no Cursor equivalent. A parameterised
  # deny rule in a form this module cannot translate fails the build.
  untranslated = lib.filter (
    rule:
    lib.hasInfix "(" rule
    && builtins.match bashRule rule == null
    && builtins.match readRule rule == null
  ) rules.deny;
  cursorHooks =
    assert lib.assertMsg (
      untranslated == [ ]
    ) "cursor.nix cannot translate these deny rules: ${toString untranslated}";
    lib.optionalAttrs (deniedCommands != [ ]) {
      beforeShellExecution = [ { command = shellHook; } ];
    }
    // lib.optionalAttrs (deniedReads != [ ]) {
      beforeReadFile = [ { command = readHook; } ];
      beforeTabFileRead = [ { command = readHook; } ];
    };

  cursorAgentSources = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) (
    builtins.readDir "${ai}/agents/codex"
  );
  cursorAgentFiles =
    lib.mapAttrs' (
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
    ) cursorAgentSources
    # Agents that ai-sauce ships in Cursor's own format (pstack's, copied from
    # upstream) replace the copy rendered from TOML, so keys like is_background survive.
    // lib.mapAttrs' (filename: _: {
      name = ".cursor/agents/${filename}";
      value = {
        force = true;
        source = "${ai}/agents/cursor/${filename}";
      };
    }) (builtins.readDir "${ai}/agents/cursor");

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
  cursorCliConfig = {
    # cursor-agent replaces itself under ~/.local on every run unless its channel is "static".
    channel = "static";
    # Sandbox shell commands, networked through sandbox.json only (no Cursor defaults).
    sandbox = {
      mode = "enabled";
      networkAccess = "user_config_only";
    };
    # No "Made with Cursor" trailer on commits, matching Claude Code's empty attribution.
    attribution.attributeCommitsToAgent = false;
  };
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
    # pstack's per-role models. The plugin copy makes the rule always apply, and
    # the pstack skills read the ~/.cursor/rules copy by path.
    ".cursor/plugins/local/ai-sauce/rules/pstack-models.mdc".source = "${ai}/pstack/for-cursor.mdc";
    ".cursor/rules/pstack-models.mdc".source = "${ai}/pstack/for-cursor.mdc";

    # A key set here replaces the in-app allowlist of that type, and Cursor
    # Settings shows it read-only. Which run mode is active stays a UI choice.
    ".cursor/permissions.json".text = builtins.toJSON cursorPermissions;
    # Same domains as Claude's sandbox and Codex's network proxy.
    ".cursor/sandbox.json".text = builtins.toJSON {
      networkPolicy = {
        default = "deny";
        allow = import ../agent-network-domains.nix;
      };
    };
    ".cursor/hooks.json".text = builtins.toJSON {
      version = 1;
      hooks = cursorHooks;
    };
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

  # The CLI rewrites this file (login, settings), so merge the managed keys in on switch.
  home.activation.cursorCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${../scripts/merge-cursor-settings.sh} \
      "$HOME/.cursor/cli-config.json" \
      "${pkgs.writeText "cursor-cli-config.json" (builtins.toJSON cursorCliConfig)}" \
      "${pkgs.jq}/bin/jq"
  '';
}
