{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (builtins.readFile ../dotfiles/oh-my-posh/config.json)
    );
  };
}
