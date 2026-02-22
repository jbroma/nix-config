{
  config,
  pkgs,
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

    globalConfig = {
      hooks = {
        enter = "mise i -q";
      };

      tools = {
        node = "lts";
        ruby = "3.3";
        java = "zulu-17";
        python = "3.12";
        rust = "1.88";
      };

      settings = {
        experimental = true;
        trusted_config_paths = [ "${config.xdg.configHome}/mise/projects" ];

        idiomatic_version_file_enable_tools = [
          "ruby"
          "node"
          "python"
        ];

        ruby = {
          ruby_build_opts = configureOpts;
        };
      };
    };
  };
}
