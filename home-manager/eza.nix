{ ... }:

{
  programs.eza = {
    enable = true;
    # adds ls aliases to zsh
    enableZshIntegration = true;
    icons = "never";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--hyperlink"
      "--time-style=+%d %b %y %H:%M:%S"
    ];
  };
}
