{
  config,
  lib,
  pkgs,
  type,
  ...
}:
let
  cursorExtensionsPath = builtins.path {
    path = ../dotfiles/vscode/extensions.json;
    name = "source";
  };
  cursorSettingsPath = builtins.path {
    path = ../dotfiles/vscode/settings.json;
    name = "source";
  };

  # Read extensions from JSON file
  extensionsJson = builtins.fromJSON (builtins.readFile cursorExtensionsPath);
  userSettingsJson = builtins.fromJSON (builtins.readFile cursorSettingsPath);
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.cursor;
    mutableExtensionsDir = false;
    profiles.default.userSettings = userSettingsJson // {
      "nix.serverPath" = "${pkgs.nil}/bin/nil";
      "nix.enableLanguageServer" = true;
      "nix.serverSettings" = {
        "nil" = {
          "formatting" = {
            "command" = [ "${pkgs.nixfmt-rfc-style}/bin/nixfmt" ];
          };
        };
      };
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
      };
    };
    profiles.default.extensions = builtins.map (
      extId:
      let
        parts = builtins.split "\\." extId;
        publisher = builtins.elemAt parts 0;
        extensionName = builtins.elemAt parts 2;
      in
      pkgs.open-vsx.${publisher}.${extensionName}
    ) extensionsJson;
  };
}
