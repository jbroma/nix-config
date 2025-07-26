{
  description = "System configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      darwin,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      darwinModules = [
        ./configuration.nix
        home-manager.darwinModules.home-manager
      ];

      configuration = {
          system,
          type ? "personal",
      }:
      let
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfreePredicate =
          pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "Xcode.app"
          ];
        };
      in
      darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit type; };
        modules = darwinModules ++ [
          {
            nixpkgs.overlays = [
              (self: super: {
                xcode = pkgs.darwin.xcode_16_4;
                ghostty = pkgs.ghostty-bin;
              })
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
      };
    };
}