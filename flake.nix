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
      # `llmServerAddress = "<ip or hostname>";` on clients. Containers reach a local Ollama at
      # the vmnet gateway. Consumed by macos/llm-*.nix and home-manager/llm.nix.
      llmRole =
        let
          server = user.llmServer or false;
          # Ollama's port and the models the server pulls at login (first one is the default),
          # shared by the service, the firewall, the clients' OLLAMA_HOST and the sandbox's Pi config.
          port = 11434;
          models = [
            "qwen3.8:27b-mlx"
            "gemma4:26b-mlx"
          ];
          model = builtins.head models;
          # A client's server address; null on the server itself and on machines with no role.
          host = user.llmServerAddress or null;
          clients = user.llmClients or [ ];
          octet = "(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])";
          label = "[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?";
          # A DNS name (the router's <name>.internal records) or an IPv4 literal.
          isHost = s: builtins.isString s && builtins.match "${label}(\\.${label})*" s != null;
          isCidr =
            s:
            builtins.isString s && builtins.match "(${octet}\\.){3}${octet}(/([12]?[0-9]|3[0-2]))?" s != null;
        in
        assert
          !(server && host != null)
          || throw "user.nix: llmServerAddress is ignored when llmServer = true; remove one";
        assert
          host == null
          || isHost host
          || throw "user.nix: llmServerAddress must be a hostname or IPv4 address string, got ${builtins.toJSON host}";
        # pf tables load at boot with no resolver: the client allowlist must be IP literals.
        assert
          (builtins.isList clients && builtins.all isCidr clients)
          || throw "user.nix: llmClients must be a list of IPv4 address or CIDR strings, got ${builtins.toJSON clients}";
        {
          inherit
            server
            host
            clients
            port
            models
            model
            ;
        };

      # Independent of the model server. Profiles have distinct source ranges so setting
      # HTTP_PROXY inside an offline guest cannot grant it internet or model access.
      sandboxRole = rec {
        enable = user.agentSandbox or false;
        proxyPort = 11436;
        subnets = {
          offline = "10.171.71.0/24";
          model = "10.171.72.0/24";
          internet = "10.171.73.0/24";
        };
        networks = lib.mapAttrs (
          profile: subnet:
          lib.genList (slot: {
            name = "agent-sandbox-${profile}-${toString slot}";
            subnet = "${lib.removeSuffix ".0/24" subnet}.${toString (slot * 8)}/29";
            gateway = "${lib.removeSuffix ".0/24" subnet}.${toString (slot * 8 + 1)}";
          }) 32
        ) subnets;
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
          sandbox ? sandboxRole // {
            enable = sandboxRole.enable || llm.server;
          },
        }:
        inputs.darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit
              type
              user
              ai
              llm
              sandbox
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
        personal-agent-sandbox = configuration {
          type = "personal";
          llm = llmRole // {
            server = false;
            host = null;
          };
          sandbox = sandboxRole // {
            enable = true;
          };
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;
    };
}
