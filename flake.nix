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

      # Local-LLM role, from user.nix (never committed): `llmServer = true;` on the machine that
      # runs Ollama, with `llmClients = [ "<cidr>" ... ];` naming who may reach its API;
      # `llmServerAddress = "<ip>";` on clients. Containers reach a local Ollama at the vmnet
      # gateway. Consumed by macos/llm-*.nix and home-manager/llm.nix.
      llmRole =
        let
          server = user.llmServer or false;
          # Ollama's port and the default model, shared by the service, the firewall, the
          # clients' OLLAMA_HOST and the sandbox's Pi config.
          port = 11434;
          model = "qwen3.8:27b-mlx";
          # The sandbox runs on its own host-only container network; its gateway is the host.
          sandboxSubnet = "10.171.71.0/24";
          sandboxGateway = "10.171.71.1";
          # A client's server address; null on the server itself and on machines with no role.
          host = user.llmServerAddress or null;
          clients = user.llmClients or [ ];
          octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])";
          isIPv4 = s: builtins.isString s && builtins.match "(${octet}\\.){3}${octet}" s != null;
          isCidr =
            s:
            builtins.isString s && builtins.match "(${octet}\\.){3}${octet}(/([12]?[0-9]|3[0-2]))?" s != null;
        in
        # Containers resolve nothing and pf tables load at boot: addresses must be IP literals.
        assert
          !(server && host != null)
          || throw "user.nix: llmServerAddress is ignored when llmServer = true; remove one";
        assert
          host == null
          || isIPv4 host
          || throw "user.nix: llmServerAddress must be an IPv4 address string, got ${builtins.toJSON host}";
        assert
          (builtins.isList clients && builtins.all isCidr clients)
          || throw "user.nix: llmClients must be a list of IPv4 address or CIDR strings, got ${builtins.toJSON clients}";
        {
          inherit
            server
            host
            clients
            port
            model
            sandboxSubnet
            sandboxGateway
            ;
        };

      # The server-only code paths never evaluate on a machine whose user.nix has no role;
      # `personal-llm-server` builds them with the role forced on (mise run check-llm-server).
      llmServerForced = llmRole // {
        server = true;
        host = null;
        clients = [ "192.0.2.0/24" ];
      };

      darwinModules = [
        ./configuration.nix
        inputs.home-manager.darwinModules.home-manager
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];

      # ai = null builds a bootstrap profile without the private AI tool config.
      configuration =
        {
          type,
          ai ? inputs.ai,
          llm ? llmRole,
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              type
              user
              ai
              llm
              ;
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
            (
              { config, ... }:
              {
                # Immutable taps: the Brewfile must list the same taps nix-homebrew provisions.
                homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
              }
            )
            {
              nixpkgs.overlays = [
                (
                  final: _:
                  # Every file or directory in ./pkgs is a package of the same name.
                  lib.mapAttrs' (name: _: {
                    name = lib.removeSuffix ".nix" name;
                    value = final.callPackage (./pkgs + "/${name}") { };
                  }) (builtins.readDir ./pkgs)
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
          ai = null;
        };
        personal-bootstrap = configuration {
          type = "personal";
          ai = null;
        };
        personal-llm-server = configuration {
          type = "personal";
          llm = llmServerForced;
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
