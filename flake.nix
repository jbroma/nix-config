{
  description = "System configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-nikitabobko = {
      url = "github:nikitabobko/homebrew-tap";
      flake = false;
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ai = {
      url = "git+ssh://git@github.com/jbroma/ai-sauce.git";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs.lib;
      system = "aarch64-darwin";
      allowedUnfreePackages = [
        # "Xcode.app"
        "1password"
        "1password-cli"
        "1password-gui"
        "android-studio"
        "claude-code"
        "claude-desktop"
        "cleanshot-x"
        "codex-app"
        "codex-cli"
        "cursor"
        "google-chrome"
        "lmstudio"
        "maestro-studio"
        "obsidian"
        "orbstack"
        "raycast"
        "slack"
        "spotify"
        "vscode-extension-mhutchie-git-graph"
      ];
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) allowedUnfreePackages;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = allowUnfreePredicate;
      };

      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      user = import ./user.nix;
      utils = import ./lib.nix;

      # Automatically call all packages in ./pkgs
      customPkgs = pkgs.lib.attrsets.mapAttrs' (name: _: {
        name = pkgs.lib.strings.removeSuffix ".nix" name;
        value = pkgs.callPackage (./pkgs + "/${name}") { };
      }) (builtins.readDir ./pkgs);

      darwinModules = [
        ./configuration.nix
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];

      configuration =
        {
          type ? "personal",
          enableAi ? true,
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              type
              user
              utils
              allowedUnfreePackages
              enableAi
              ;
            ai = if enableAi then inputs.ai else null;
          };
          modules = darwinModules ++ [
            {
              nix-homebrew = {
                enable = true;
                user = user.username;
                enableRosetta = false;
                mutableTaps = false;
                taps = {
                  "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko;
                };
              };
            }
            {
              homebrew.taps = [ "nikitabobko/tap" ];
            }
            {
              nixpkgs.overlays = [
                (_: super: {
                  # xcode = pkgs.darwin.xcode_26;
                  android-studio = customPkgs.android-studio;
                  minisim = customPkgs.minisim;
                  claude-code = customPkgs.claude-code;
                  claude-desktop = customPkgs.claude-desktop;
                  cursor = customPkgs.cursor;
                  cleanshot-x = customPkgs.cleanshot-x;
                  codex-cli = customPkgs.codex-cli;
                  codex-app = customPkgs.codex-app;
                  lmstudio = super.lmstudio.overrideAttrs (old: {
                    # nixpkgs' darwin.sigtool-provided codesign does not support --deep, but LM
                    # Studio needs a recursive re-sign after patching its bundled JavaScript.
                    installPhase =
                      builtins.replaceStrings
                        [ "codesign --force --deep --sign -" ]
                        [ "/usr/bin/codesign --force --deep --sign -" ]
                        old.installPhase;
                  });
                  maestro-studio = customPkgs.maestro-studio;
                  spotify = customPkgs.spotify;
                  wsmancli = customPkgs.wsmancli;
                  zed-editor = customPkgs.zed-editor;
                  worktrunk = customPkgs.worktrunk;
                  vite-plus = customPkgs.vite-plus;
                })
                inputs.nix-vscode-extensions.overlays.default
              ];
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        work = configuration { type = "work"; };
        personal = configuration { type = "personal"; };
        work-bootstrap = configuration {
          type = "work";
          enableAi = false;
        };
        personal-bootstrap = configuration {
          type = "personal";
          enableAi = false;
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
