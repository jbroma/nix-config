# OpenAI Codex - AI coding agent desktop app
# https://developers.openai.com/codex
# Version extracted from Codex.app/Contents/Info.plist CFBundleShortVersionString after build
{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:
let
  version = "26.217.1959";
in
stdenv.mkDerivation {
  pname = "codex-app";
  inherit version;

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg";
    hash = "sha256-0YLr6GnCilNGmpZ27CDH7bTzkYZ5wIh6ILFvGaNBfhs=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -r "Codex.app" "$out/Applications/Codex.app"

    # Verify version matches what we expect
    actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$out/Applications/Codex.app/Contents/Info.plist")
    if [ "$actual" != "${version}" ]; then
      echo "ERROR: Version mismatch! Expected ${version}, got $actual" >&2
      echo "Update the version in codex-app.nix to: $actual" >&2
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "OpenAI's coding agent desktop app for macOS";
    homepage = "https://openai.com/index/introducing-codex";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
  };
}
