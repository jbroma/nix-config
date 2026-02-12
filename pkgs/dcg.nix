# Destructive Command Guard (dcg) - AI coding agent safety hook
# https://github.com/Dicklesworthstone/destructive_command_guard
{
  lib,
  stdenv,
  fetchurl,
  xz,
}:
let
  version = "0.4.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v${version}/dcg-aarch64-apple-darwin.tar.xz";
      hash = "sha256-Kg1ZTx7FSxqUU8N2xKnGJ371SMhp9gusRsvSKSglHoM=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "dcg";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  nativeBuildInputs = [ xz ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp dcg $out/bin/dcg
    chmod +x $out/bin/dcg

    runHook postInstall
  '';

  meta = {
    description = "High-performance hook that blocks destructive commands before they execute";
    homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
    license = lib.licenses.mit;
    mainProgram = "dcg";
    platforms = [ "aarch64-darwin" ];
  };
}
