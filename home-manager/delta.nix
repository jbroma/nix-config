{ ... }:

{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      hyperlinks = true;
      line-numbers = true;
      syntax-theme = " Visual Studio Dark+";
    };
  };
}
