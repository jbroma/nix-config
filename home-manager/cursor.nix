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
  };

  managedCursorSettingsFile = pkgs.writeText "cursor-managed-settings.json" (
    builtins.toJSON managedCursorSettings
  );
  cursorMcpServers = lib.mapAttrs (
    _: server: if server ? type then server else server // { type = "stdio"; }
  ) config.mcp.servers;
  cursorMcpConfigFile = pkgs.writeText "cursor-mcp.json" (
    builtins.toJSON {
      mcpServers = cursorMcpServers;
    }
  );
  cursorAgentSources = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".toml" name) (
    builtins.readDir "${ai}/agents"
  );
  cursorAgentFiles = lib.mapAttrs' (
    filename: _:
    let
      agentName = lib.removeSuffix ".toml" filename;
      agent = builtins.fromTOML (builtins.readFile "${ai}/agents/${filename}");
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
      oxc.oxc-vscode
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
  home.file = {
    ".cursor/mcp.json".source = cursorMcpConfigFile;
    ".cursor/skills".source = "${ai}/skills";
    ".cursor/rules/core.mdc" = {
      force = true;
      text = ''
        ---
        description: Shared personal instructions from ai-sauce CORE.md
        alwaysApply: true
        ---

        ${builtins.readFile "${ai}/CORE.md"}
      '';
    };
  }
  // cursorAgentFiles
  // builtins.listToAttrs extensionLinks;

  # Keep Cursor settings mutable while applying Nix-managed settings on switch.
  home.activation.cursorSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${../scripts/merge-cursor-settings.sh} \
      "$HOME/Library/Application Support/Cursor/User/settings.json" \
      "${managedCursorSettingsFile}" \
      "${pkgs.jq}/bin/jq"
  '';
}
