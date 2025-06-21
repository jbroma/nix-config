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
        
      darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit type; };
        modules = darwinModules ++ [];
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