{ 
  pkgs, 
  lib, 
  ... 
}: 

{
  programs.lsd = { 
    enable = true; 
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