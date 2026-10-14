{ config, ... }:
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
      };

      settings = {
        experimental = true;
        trusted_config_paths = [ "${config.xdg.configHome}/mise/projects" ];

        idiomatic_version_file_enable_tools = [
          "ruby"
          "node"
          "python"
        ];

        # Only source builds (versions without a precompiled binary) read this.
        # Keep Nix store paths out: they get garbage-collected and break the build.
        ruby.ruby_build_opts = "--disable-install-doc";
      };
    };
  };
}
