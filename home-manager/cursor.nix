{
  pkgs,
  lib,
  ai,
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
  home.file = {
    # Cursor symlink
    ".cursorrules".source = "${ai}/CORE.md";
  }
  // builtins.listToAttrs extensionLinks;

  home.packages = [ pkgs.cursor ];

  # Keep Cursor settings mutable while applying Nix-managed settings on switch.
  home.activation.cursorSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${../scripts/merge-cursor-settings.sh} \
      "$HOME/Library/Application Support/Cursor/User/settings.json" \
      "${managedCursorSettingsFile}" \
      "${pkgs.jq}/bin/jq"
  '';
}
