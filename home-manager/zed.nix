{
  pkgs,
  lib,
  ...
}:
let
  zedSettingsPath = builtins.path {
    path = ../dotfiles/zed/settings.json;
    name = "source";
  };
  zedSettingsJson = builtins.fromJSON (builtins.readFile zedSettingsPath);

  zedKeymapPath = builtins.path {
    path = ../dotfiles/zed/keymap.json;
    name = "source";
  };
  zedKeymapJson = builtins.fromJSON (builtins.readFile zedKeymapPath);
in
{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
    extensions = [
      # Git
      "git-firefly"
      # Languages
      "rust"
      "python"
      "dockerfile"
      "sql"
      "mdx"
      "nix"
      "toml"
      "xml"
      "yaml"
      # JS/TS ecosystem
      "biome"
      "prettier"
      "html"
      # Themes
      "github-theme"
    ];
    # Merge dotfile settings with Nix-managed paths
    userSettings = lib.recursiveUpdate zedSettingsJson {
      # Nix-specific: language server paths
      languages.Nix = {
        formatter = {
          external = {
            command = "${pkgs.nixfmt}/bin/nixfmt";
            arguments = [ ];
          };
        };
        language_servers = [
          "nil"
          "!nixd"
        ];
      };
      lsp.nil = {
        binary = {
          path = "${pkgs.nil}/bin/nil";
        };
        settings = {
          nil = {
            formatting = {
              command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
            };
          };
        };
      };
    };
    userKeymaps = zedKeymapJson;
  };
}
