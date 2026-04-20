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
  version = "1.3109.0";
in
stdenv.mkDerivation {
  pname = "claude-desktop";
  inherit version;

  src = fetchurl {
    url = "https://downloads.claude.ai/releases/darwin/universal/1.3109.0/Claude-35cbf6530e05912137624cde0f075dc7f121fa60.zip";
    hash = "sha256-8VlpPr7NimKM/ogskToZefyaSx07yaIYBR8PEVyIu2g=";
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
