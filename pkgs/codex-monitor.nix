{
  stdenv,
  lib,
  fetchurl,
}:
let
  version = "0.7.60";
in
stdenv.mkDerivation {
  pname = "codex-monitor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Dimillian/CodexMonitor/releases/download/v${version}/CodexMonitor.app.tar.gz";
    hash = "sha256-BTDq+GdwfY/a215lNs7M5nCdxp+25ZD5xd1J6ZpK8Kc=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -r "Codex Monitor.app" "$out/Applications/Codex Monitor.app"

    runHook postInstall
  '';

  meta = {
    description = "Menu bar app to monitor Codex sessions";
    homepage = "https://github.com/Dimillian/CodexMonitor";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
  };
}
