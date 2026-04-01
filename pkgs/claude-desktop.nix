{
  stdenv,
  lib,
  fetchurl,
  unzip,
  writeShellApplication,
  curl,
  git,
  jq,
  nix,
  perl,
  ripgrep,
}:
let
  version = "1.1.9669";
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version;

  src = fetchurl {
    url = "https://downloads.claude.ai/releases/darwin/universal/1.1.9669/Claude-aea25dadb1a5850303cbd7f3126691a15dc41963.zip";
    hash = "sha256-Th1dX2n+8Yzf8k9nD7pW3Yfq5N+ux8HtY8bVQrEm7vU=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -r "Claude.app" "$out/Applications/Claude.app"

    actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$out/Applications/Claude.app/Contents/Info.plist")
    if [ "$actual" != "${version}" ]; then
      echo "ERROR: Version mismatch! Expected ${version}, got $actual" >&2
      echo "Update the version in claude-desktop.nix to: $actual" >&2
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "Anthropic's official Claude AI desktop app";
    homepage = "https://claude.com/download";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  passthru.updateScript = writeShellApplication {
    name = "update-claude-desktop";
    runtimeInputs = [
      curl
      git
      jq
      nix
      perl
      ripgrep
    ];
    text = builtins.readFile ../scripts/update-claude-desktop.sh;
  };
}
