{
  pkgs,
  ...
}:
let
  cursorSettingsPath = builtins.path {
    path = ../dotfiles/vscode/settings.json;
    name = "source";
  };
  cursorSettingsJson = builtins.fromJSON (builtins.readFile cursorSettingsPath);
in
{
  programs.vscode = {
    enable = true;
    package = pkgs.cursor;
    mutableExtensionsDir = true;
    profiles.default.userSettings = cursorSettingsJson // {
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
    profiles.default.extensions =
      (with pkgs.vscode-marketplace; [
        biomejs.biome
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
      ])
      ++ (with pkgs.vscode-extensions; [
        vadimcn.vscode-lldb
        unifiedjs.vscode-mdx
      ]);
  };
}
