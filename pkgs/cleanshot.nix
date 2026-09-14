{
  stdenvNoCC,
  lib,
  fetchurl,
  _7zz,
}:
stdenvNoCC.mkDerivation rec {
  pname = "cleanshot";
  # License covers 4.x only. Do not update to 5.x.
  version = "4.8.10";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${version}.dmg";
    sha256 = "0f1b1cdda9a93908ced0341abb0d505adc55e51d145562013085b1e70f366d84";
  };

  nativeBuildInputs = [ _7zz ];
  unpackPhase = ''
    runHook preUnpack
    # Exclude macOS metadata streams that 7-Zip would create as unsigned files.
    7zz x "$src" '-xr!*:com.apple.*'
    runHook postUnpack
  '';
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "CleanShot X.app" "$out/Applications/"
    test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$out/Applications/CleanShot X.app/Contents/Info.plist")" = "${version}"
    runHook postInstall
  '';

  meta = {
    description = "Screen capturing tool";
    homepage = "https://cleanshot.com/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
  };
}
