{ pkgs, ... }:

let
  yamlFormat = pkgs.formats.yaml { };
  pnpmYamlConfig = yamlFormat.generate "pnpm-config.yaml" {
    enableGlobalVirtualStore = true;
  };
in
{
  home.file.".config/pnpm/config.yaml".source = pnpmYamlConfig;
  home.file."Library/Preferences/pnpm/config.yaml".source = pnpmYamlConfig;
}
