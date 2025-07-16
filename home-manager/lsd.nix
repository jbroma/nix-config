{ 
  pkgs, 
  lib, 
  ... 
}: 

{
  programs.lsd = { 
    enable = true; 
    # adds ls aliases to zsh
    # reference: https://github.com/nix-community/home-manager/blob/e8c19a3cec2814c754f031ab3ae7316b64da085b/modules/programs/lsd.nix#L106-L113
    enableZshIntegration = true;
    settings = {
      size = "short";
      total-size = false;
      indicators = false;
      hyperlink = "always";
      icons = {
        when = "never";
      };
      date = "+%d %b %y %H:%M:%S";
      blocks = [
        "date"
        "size"
        "name"
      ];
      sorting = {
        dir-grouping = "first";
      };
      # symlinks
      dereference = true;
      no-symlink = false;
      symlink-arrow = "->";
    };
  };
}