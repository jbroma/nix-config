{
  pkgs,
  lib,
  ...
}:
let
  configureOpts = builtins.concatStringsSep " " [
    "--with-libyaml-include=${pkgs.libyaml.dev}/include"
    "--with-libyaml-lib=${pkgs.libyaml.out}/lib"
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
        idiomatic_version_file_enable_tools = [
          "ruby"
          "node"
        ];

        ruby = {
          ruby_build_opts = configureOpts;
        };
      };
    };
  };
}
