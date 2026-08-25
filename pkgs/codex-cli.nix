# OpenAI Codex - AI coding agent for terminal
# https://github.com/openai/codex
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.149.1";

  # codex-package bundles codex plus the codex-code-mode-host helper and
  # resources (rg, zsh) that codex resolves relative to its own binary.
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-aarch64-apple-darwin.tar.gz";
      hash = "sha256-TLsXRotdhrSxgqKMAW1i6dJzokHOwEiFzPrnbmmDrj8=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex-cli";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R bin codex-path codex-resources codex-package.json $out/
    chmod +x $out/bin/* $out/codex-path/* $out/codex-resources/zsh/bin/*

    runHook postInstall
  '';

  meta = {
    description = "OpenAI's coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.unfree;
    mainProgram = "codex";
    platforms = [ "aarch64-darwin" ];
  };
}
