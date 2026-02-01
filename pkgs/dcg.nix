# Destructive Command Guard (dcg) - AI coding agent safety hook
# https://github.com/Dicklesworthstone/destructive_command_guard
{
  lib,
  stdenv,
  fetchurl,
  xz,
}:
let
  version = "0.2.15";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v${version}/dcg-aarch64-apple-darwin.tar.xz";
      hash = "sha256-4gWpCQ3Q3vpbk69ODJ9VViPadgsH2jC2qkYZBWkiJR4=";
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
