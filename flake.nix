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
      system = "aarch64-darwin";
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (inputs.nixpkgs.lib.getName pkg) [
            # "Xcode.app"
            "cursor"
          ];
      };

      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixfmt.enable = true;
      };

      user = import ./user.nix;

      # Automatically call all packages in ./pkgs
      customPkgs = pkgs.lib.attrsets.mapAttrs' (name: _: {
        name = pkgs.lib.strings.removeSuffix ".nix" name;
        value = pkgs.callPackage (./pkgs + "/${name}") { };
      }) (builtins.readDir ./pkgs);

      darwinModules = [
        ./configuration.nix
        inputs.home-manager.darwinModules.home-manager
      ];

      configuration =
        {
          type ? "personal",
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit type user;
            ai = inputs.ai;
          };
          modules = darwinModules ++ [
            {
              nixpkgs.overlays = [
                (_: super: {
                  # xcode = pkgs.darwin.xcode_26;
                  ghostty = pkgs.ghostty-bin;
                  android-studio = customPkgs.android-studio;
                  minisim = customPkgs.minisim;
                  claude-island = customPkgs.claude-island;
                  cursor = pkgs.code-cursor;
                  cleanshot-x = customPkgs.cleanshot-x;
                  spotify = super.spotify.overrideAttrs (oldAttrs: {
                    src =
                      if (super.stdenv.isDarwin && super.stdenv.isAarch64) then
                        super.fetchurl {
                          url = "https://web.archive.org/web/20251029235406/https://download.scdn.co/SpotifyARM64.dmg";
                          hash = "sha256-0gwoptqLBJBM0qJQ+dGAZdCD6WXzDJEs0BfOxz7f2nQ=";
                        }
                      else
                        oldAttrs.src;
                  });
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
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
