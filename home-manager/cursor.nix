{
  config,
  lib,
  pkgs,
  type,
  ...
}:
let
  cursor = pkgs.cursor;
  cursorUserDir = "Library/Application Support/Cursor/User";
  cursorExtensionsPath = "../dotfiles/vscode/extensions.json";
  cursorSettingsPath = "../dotfiles/vscode/settings.json";

  # Read extensions from JSON file
  extensionsJson = builtins.fromJSON (builtins.readFile cursorExtensionsPath);
in
{
  home.activation.writableFile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cp ${cursorSettingsPath} "${cursorUserDir}/settings.json"
    chmod u+w "${cursorUserDir}/settings.json"
  '';

  programs.cursor = {
    enable = true;
    package = cursor;
    mutableExtensionsDir = false;
    extensions = builtins.map (extId: pkgs.vscode-extensions.${extId}) extensionsJson;
  };
}
