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

  managedCursorSettingsJson = builtins.toJSON managedCursorSettings;

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
    cursor_settings_file="$HOME/Library/Application Support/Cursor/User/settings.json"
    cursor_settings_dir="$(dirname "$cursor_settings_file")"
    managed_settings_json=${lib.escapeShellArg managedCursorSettingsJson}

    mkdir -p "$cursor_settings_dir"

    if [ -L "$cursor_settings_file" ]; then
      rm -f "$cursor_settings_file"
    fi

    if [ ! -f "$cursor_settings_file" ]; then
      printf '%s\n' "$managed_settings_json" > "$cursor_settings_file"
      exit 0
    fi

    if existing_settings_json="$(${pkgs.jq}/bin/jq -c '.' "$cursor_settings_file" 2>/dev/null)"; then
      :
    else
      existing_settings_json='{}'
    fi

    tmp_file="$(mktemp "''${cursor_settings_file}.tmp.XXXXXX")"
    ${pkgs.jq}/bin/jq -n \
      --argjson existing "$existing_settings_json" \
      --argjson managed "$managed_settings_json" \
      '($existing // {}) * ($managed // {})' > "$tmp_file"

    mv "$tmp_file" "$cursor_settings_file"
  '';
}
