{ ... }: 

{
  programs.mise = { 
    enable = true; 
    enableZshIntegration = true;
    globalConfig = {
      tools = {
        node = "lts";
        ruby = "3.3";
        java = "zulu-17";
      };
    };
  };
}