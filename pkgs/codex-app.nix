# OpenAI Codex - AI coding agent desktop app
# https://developers.openai.com/codex
# Version extracted from Codex.app/Contents/Info.plist CFBundleShortVersionString after build
{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:
let
  version = "26.611.62324";
in
stdenv.mkDerivation {
  pname = "codex-app";
  inherit version;

  src = fetchurl {
    name = "Codex-${version}.dmg";
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg?version=${version}";
    hash = "sha256-MdjiZmoIlagw3wgy3ECDroKm6b0mYDFBwCk6zqZhghE=";
  };

  nativeBuildInputs = [ _7zz ];

  sourceRoot = ".";

  unpackCmd = "7zz x -snld -xr'!*:com.apple.*' \"$curSrc\"";

  installPhase = ''
    runHook preInstall

    app_bundle=$(find . -maxdepth 3 -type d -name "Codex.app" -print -quit)
    if [ -z "$app_bundle" ]; then
      echo "ERROR: Codex.app not found in DMG" >&2
      find . -maxdepth 3 -print >&2
      exit 1
    fi

    mkdir -p "$out/Applications"
    cp -R "$app_bundle" "$out/Applications/Codex.app"

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
