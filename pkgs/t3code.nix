# T3 Code - GUI for the Claude Code and Codex CLIs
# https://github.com/pingdotgg/t3code
# nixpkgs builds from source and trails releases; this uses the signed release app.
{
  stdenvNoCC,
  lib,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "t3code";
  version = "0.0.42";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.zip";
    hash = "sha256-BmOznpeQ8Hayp0uUReEXziu26CTQYZxXjoCLS6crRjc=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "T3 Code (Alpha).app" "$out/Applications/"
    test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$out/Applications/T3 Code (Alpha).app/Contents/Info.plist")" = "${version}"
    runHook postInstall
  '';

  meta = {
    description = "Minimal GUI for coding agents";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
  };
}
