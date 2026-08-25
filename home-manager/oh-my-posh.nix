_:

{
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromJSON (builtins.readFile ../dotfiles/oh-my-posh/config.json);
  };
}
