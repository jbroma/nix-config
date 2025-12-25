{
  description = "System configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      nix-vscode-extensions,
      ...
    }@inputs:
    let
      user = import ./user.nix;

      darwinModules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
      ];

      configuration =
        {
          system,
          type ? "personal",
        }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "Xcode.app"
                "cursor"
              ];
          };
          # automatically call all packages in ./pkgs
          customPkgs = pkgs.lib.attrsets.mapAttrs' (name: value: {
            name = pkgs.lib.strings.removeSuffix ".nix" name;
            value = pkgs.callPackage (./pkgs + "/${name}") { };
          }) (builtins.readDir ./pkgs);
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit type user;
          };
          modules = darwinModules ++ [
            {
              nixpkgs.overlays = [
                (self: super: {
                  xcode = pkgs.darwin.xcode_26;
                  ghostty = pkgs.ghostty-bin;
                  android-studio = customPkgs.android-studio;
                  minisim = customPkgs.minisim;
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
                nix-vscode-extensions.overlays.default
              ];
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        work = configuration {
          system = "aarch64-darwin";
          type = "work";
        };
        personal = configuration {
          system = "aarch64-darwin";
          type = "personal";
        };
      };

      formatter = inputs.nixpkgs.nixfmt-rfc-style;
    };
}
