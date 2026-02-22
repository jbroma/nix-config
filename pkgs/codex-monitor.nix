{
  stdenv,
  lib,
  fetchurl,
}:
let
  version = "0.7.56";
in
stdenv.mkDerivation {
  pname = "codex-monitor";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Dimillian/CodexMonitor/releases/download/v${version}/CodexMonitor.app.tar.gz";
    hash = "sha256-wIE2Vi5plD+d7XqrGOptXNagHN/LcRWeMhnj4oifueA=";
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
