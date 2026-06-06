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
  version = "1.11187.4";
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version;

  src = fetchurl {
    url = "https://downloads.claude.ai/releases/darwin/universal/1.11187.4/Claude-58400536f3ccde1cff9a129de6c3112dc8cb489a.zip";
    hash = "sha256-qyVqIlNz1Y1PgBY940OOB2+i0E114w7MvubZ1LSx/Fs=";
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
