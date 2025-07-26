{ ... }:

{
  programs.git.delta = {
    enable = true;
    options = {
      hyperlinks = true;
      line-numbers = true;
      syntax-theme = " Visual Studio Dark+";
    };
  };
}
