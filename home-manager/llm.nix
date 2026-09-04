# Local-LLM tooling (role from flake.nix `llm`): on the server the Ollama service and the
# pi-sandbox command; on clients the Ollama CLI pointed at the server; on machines with no role
# the local-only Ollama service as before. Vault note: Homelab/LLM Server.md
{
  config,
  lib,
  pkgs,
  llm,
  ...
}:

let
  # Coding agents need 64k+; Ollama's default is 4k. Shared with the sandbox's Pi config.
  contextLength = 131072;
  client = llm.host != null;
  ollamaPort = if llm.server then llm.port + 1 else llm.port;

  # The sandbox must never reach model management: /api/pull can make the host fetch URLs.
  # Keep the raw API on loopback, and check the socket peer, never forwarded client headers.
  # Sandbox rules come first even if llm.clients includes its subnet. Everything else is denied.
  proxyConfig = pkgs.writeText "llm-proxy.Caddyfile" ''
    {
      admin off
      auto_https off
      persist_config off
    }
    http://:${toString llm.port} {
      route {
        @sandbox remote_ip ${llm.sandboxSubnet}
        handle @sandbox {
          @chat {
            method POST
            path /v1/chat/completions
          }
          handle @chat {
            reverse_proxy 127.0.0.1:${toString ollamaPort} {
              header_up Host {upstream_hostport}
            }
          }
          respond 403
        }
        @trusted remote_ip 127.0.0.1 ::1 ${lib.concatStringsSep " " llm.clients}
        handle @trusted {
          reverse_proxy 127.0.0.1:${toString ollamaPort} {
            header_up Host {upstream_hostport}
          }
        }
        respond 403
      }
    }
  '';

  pi-sandbox = pkgs.writeShellApplication {
    name = "pi-sandbox";
    runtimeInputs = [
      pkgs.apple-container
      pkgs.jq
    ];
    runtimeEnv = {
      LLM_SERVER = llm.sandboxGateway;
      LLM_PORT = toString llm.port;
      LLM_MODEL_DEFAULT = llm.model;
      LLM_CONTEXT = toString contextLength;
      SANDBOX_NETWORK = "llm-sandbox";
      SANDBOX_SUBNET = llm.sandboxSubnet;
      # Interpolated so the directory is copied to the store: its hash is the image tag.
      PI_SANDBOX_CONTEXT = "${../containers/pi-sandbox}";
    };
    text = builtins.readFile ../scripts/pi-sandbox.sh;
  };

  # Homebrew's ollama links mlx-c (MLX backend); nixpkgs builds with OLLAMA_MLX_BACKENDS="".
  # A missing formula fails fast; launchd retries on ThrottleInterval (a clean exit would stop
  # the agent for good, and a rebuild with an unchanged plist never restarts it).
  ollama = pkgs.writeShellScriptBin "ollama" ''
    [ -x /opt/homebrew/bin/ollama ] || { echo "ollama: /opt/homebrew/bin/ollama missing (brew install ollama)" >&2; exit 1; }
    exec /opt/homebrew/bin/ollama "$@"
  '';

  # Pulls the models from flake.nix in the foreground, with ollama's own progress bars (a no-op
  # once they are present). Run after a rebuild; a stale Homebrew ollama rejects new model
  # formats with a 412, hence the version line and the upgrade hint.
  ollama-models = pkgs.writeShellApplication {
    name = "ollama-models";
    runtimeInputs = [ ollama ];
    text = ''
      echo "server version: $(ollama -v 2>/dev/null || echo "not answering (launchctl kickstart -k gui/$(id -u)/org.nix-community.home.ollama)")"
      echo "on a 412 'newer version' error: mise run homebrew-upgrade"
      for model in ${lib.escapeShellArgs llm.models}; do
        ollama pull "$model"
      done
      ollama list
    '';
  };

  logDir = "${config.home.homeDirectory}/.ollama/logs";
in
lib.mkMerge [
  {
    # Local-only service where nothing else is configured; the server overrides it below.
    services.ollama = {
      enable = !client;
      port = ollamaPort;
    };
  }

  (lib.mkIf client {
    # The CLI against the server; `ollama list` and friends then talk to it.
    home.packages = [ pkgs.ollama ];
    home.sessionVariables.OLLAMA_HOST = "http://${llm.host}:${toString llm.port}";
  })

  (lib.mkIf llm.server {
    home.packages = [
      pi-sandbox
      ollama-models
      pkgs.apple-container # the `container` CLI itself, for network/image/volume housekeeping
    ];

    services.ollama = {
      package = ollama;
      host = "127.0.0.1";
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = toString contextLength;
        OLLAMA_KEEP_ALIVE = "24h";
        # qwen3.8:27b + gemma4:26b resident: ~36 GB weights plus KV cache at 128k context
        # (roughly 8 GB for Qwen, 5 GB for Gemma), about 50 GB of the 128 GB.
        OLLAMA_MAX_LOADED_MODELS = "2";
        # Ollama's scheduler serves the Qwen 3.5-family models one request at a time anyway.
        OLLAMA_NUM_PARALLEL = "1";
        # Local only: no cloud models, no Ollama web search.
        OLLAMA_NO_CLOUD = "1";
      };
    };

    launchd.agents.llm-proxy = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.caddy}/bin/caddy"
          "run"
          "--config"
          "${proxyConfig}"
          "--adapter"
          "caddyfile"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 5;
        StandardOutPath = "${logDir}/proxy.log";
        StandardErrorPath = "${logDir}/proxy.log";
      };
    };

    # `ollama serve` logs to stderr only; keep the same path the Ollama app uses. The directory
    # exists before launchd opens the file. The agent lives in the login session (FileVault means
    # a reboot needs someone at the screen anyway); `mise run homebrew-upgrade` restarts it after
    # an ollama upgrade, since the running server keeps paths into the removed keg.
    launchd.agents.ollama.config = {
      StandardOutPath = "${logDir}/server.log";
      StandardErrorPath = "${logDir}/server.log";
      ThrottleInterval = 60;
      # The module's "Background" would clamp the inference server (and the MLX runner it
      # spawns) to background QoS: efficiency cores and throttled I/O.
      ProcessType = lib.mkForce "Interactive";
    };
    home.file.".ollama/logs/.keep".text = "";
  })
]
