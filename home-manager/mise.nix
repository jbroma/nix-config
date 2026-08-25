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
        java = "temurin-17";
        python = "3.12";
        rust = "1.88";
        # Not in nixpkgs; needs Node 22.12+ (the lts above).
        "npm:agent-device" = "latest";
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
