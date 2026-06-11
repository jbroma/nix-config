{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

let
  version = "3.7.27";
in
stdenv.mkDerivation {
  pname = "cursor";
  inherit version;

  src = fetchurl {
    name = "Cursor-${version}-darwin-arm64.dmg";
    url = "https://downloads.cursor.com/production/e48ee6102a199492b0c9964699bf011886708ba3/darwin/arm64/Cursor-darwin-arm64.dmg";
    hash = "sha256-od//j41KCOjO1S+H85uW6TSM3dUe6bGviSnCZw8Avus=";
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
