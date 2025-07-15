{config, ...}: 

{
  programs.bat = {
    enable = true;
    config = {
      theme = "GitHub";
      color = "always";
    };
  };
}