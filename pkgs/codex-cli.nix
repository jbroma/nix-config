# OpenAI Codex - AI coding agent for terminal
# https://github.com/openai/codex
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.98.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-aarch64-apple-darwin.tar.gz";
      hash = "sha256-PMdXcogDruDEyZTFaCENmQCrxs7GC+Aj57LApuMBglU=";
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

    mkdir -p $out/bin
    cp codex-aarch64-apple-darwin $out/bin/codex
    chmod +x $out/bin/codex

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
