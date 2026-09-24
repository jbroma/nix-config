# agent-browser - prebuilt release binary (nixpkgs lags several versions behind)
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.38.1";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-darwin-arm64";
      hash = "sha256-LmEoclkFPqlk0553ACxqNK8OWJ5VzP8l5lnvrn6JLg0=";
    };
  };

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version;

  src = fetchurl {
    inherit (src) url hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/agent-browser
    runHook postInstall
  '';

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    mainProgram = "agent-browser";
    platforms = [ "aarch64-darwin" ];
  };
}
