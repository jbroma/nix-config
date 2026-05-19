{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  pname = "bettershot";
  version = "0.2.4";

  src = fetchurl {
    url = "https://github.com/KartikLabhshetwar/better-shot/releases/download/v${version}/bettershot_${version}_aarch64.dmg";
    hash = "sha256-wiTFRPKdHc89hPWskwxUWXwIUQLVzmzL4Tl37v8Y0Os=";
  };

  nativeBuildInputs = [ _7zz ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R "bettershot/bettershot.app" "$out/Applications/bettershot.app"

    actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$out/Applications/bettershot.app/Contents/Info.plist")
    if [ "$actual" != "${version}" ]; then
      echo "ERROR: Version mismatch! Expected ${version}, got $actual" >&2
      echo "Update the version in bettershot.nix to: $actual" >&2
      exit 1
    fi

    runHook postInstall
  '';

  meta = {
    description = "Open-source screenshot capture and editing tool for macOS";
    homepage = "https://www.bettershot.site/";
    license = lib.licenses.bsd3;
    platforms = [ "aarch64-darwin" ];
  };
}
