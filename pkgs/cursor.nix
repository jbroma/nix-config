{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

let
  version = "3.7.36";
in
stdenv.mkDerivation {
  pname = "cursor";
  inherit version;

  src = fetchurl {
    name = "Cursor-${version}-darwin-arm64.dmg";
    url = "https://downloads.cursor.com/production/776d1f9d76df50a4e0aeca61819a88e7c1b861e2/darwin/arm64/Cursor-darwin-arm64.dmg";
    hash = "sha256-8wCG6Yk7Nz9IkcDCzxE2uWc1IOPij4Q/BnGHmoVH2h0=";
  };

  nativeBuildInputs = [ _7zz ];

  sourceRoot = ".";
  unpackCmd = "7zz x -snld -xr'!*:com.apple.*' \"$curSrc\"";

  # Do not rewrite files inside the notarized app bundle.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -r "Cursor Installer/Cursor.app" "$out/Applications/Cursor.app"
    ln -s "$out/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "$out/bin/cursor"

    actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$out/Applications/Cursor.app/Contents/Info.plist")
    if [ "$actual" != "${version}" ]; then
      echo "ERROR: Version mismatch! Expected ${version}, got $actual" >&2
      echo "Update the version in cursor.nix to: $actual" >&2
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "AI-powered code editor built on VS Code";
    homepage = "https://cursor.com";
    changelog = "https://cursor.com/changelog";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "cursor";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
