{
  pkgs,
  lib,
  ...
}:
let
  configureOpts = builtins.concatStringsSep " " [
    "--with-libyaml-include=${lib.getInclude pkgs.libyaml}"
    "--with-libyaml-lib=${lib.getLib pkgs.libyaml}"
    "--with-jemalloc-dir=${pkgs.jemalloc}"
    "--disable-install-doc"
    "--enable-yjit"
  ];
in
{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      experimental = true;
    };

    globalConfig = {
      hooks = {
        enter = "mise install";
      };

      tools = {
        node = "lts";
        ruby = "3.3";
        java = "zulu-17";
        rust = "1.88";
      };

      settings = {
        idiomatic_version_file_enable_tools = [ "ruby" ];

        ruby = {
          ruby_build_opts = configureOpts;
        };
      };
    };
  };
}
