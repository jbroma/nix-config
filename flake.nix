{
  description = "System configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    homebrew-malpern = {
      url = "github:malpern/homebrew-tap";
      flake = false;
    };
    homebrew-felixkratz = {
      url = "github:FelixKratz/homebrew-formulae";
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
      pkgs = inputs.nixpkgs.legacyPackages.${system};

      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
        programs.deadnix.enable = true;
        programs.statix.enable = true;
      };

      user = import ./user.nix;

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
            inherit type user enableAi;
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
                  "felixkratz/homebrew-formulae" = inputs.homebrew-felixkratz;
                  "nikitabobko/homebrew-tap" = inputs.homebrew-nikitabobko;
                  "malpern/homebrew-tap" = inputs.homebrew-malpern;
                };
              };
            }
            {
              homebrew.taps = [
                "felixkratz/formulae"
                "nikitabobko/tap"
                "malpern/tap"
              ];
            }
            {
              nixpkgs.overlays = [
                (
                  final: prev:
                  # Every file or directory in ./pkgs is a package of the same name.
                  lib.mapAttrs' (name: _: {
                    name = lib.removeSuffix ".nix" name;
                    value = final.callPackage (./pkgs + "/${name}") { };
                  }) (builtins.readDir ./pkgs)
                  // {
                    # xcode = final.darwin.xcode_26;
                    lmstudio = prev.lmstudio.overrideAttrs (old: {
                      # nixpkgs' darwin.sigtool-provided codesign does not support --deep, but LM
                      # Studio needs a recursive re-sign after patching its bundled JavaScript.
                      installPhase =
                        builtins.replaceStrings
                          [ "codesign --force --deep --sign -" ]
                          [ "/usr/bin/codesign --force --deep --sign -" ]
                          old.installPhase;
                    });
                  }
                )
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
