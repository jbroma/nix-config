# Vite+ - The Unified Toolchain for the Web
# https://viteplus.dev/guide/
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.1.12";

  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@voidzero-dev/vite-plus-cli-darwin-arm64/-/vite-plus-cli-darwin-arm64-${version}.tgz";
      hash = "sha256-32qyLd7CzvJk8liYlYcSHZbSCiddbm6vcYZnQ8NlMII=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "vite-plus";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = "package";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp vp $out/bin/vp
    chmod +x $out/bin/vp

    runHook postInstall
  '';

  meta = {
    description = "The Unified Toolchain for the Web";
    homepage = "https://viteplus.dev/guide/";
    license = lib.licenses.mit;
    mainProgram = "vp";
    platforms = [ "aarch64-darwin" ];
  };
}
