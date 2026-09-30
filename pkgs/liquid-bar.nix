{
  stdenvNoCC,
  lib,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation rec {
  pname = "liquid-bar";
  version = "0.7.0";

  src = fetchurl {
    url = "https://github.com/jbroma/liquid-bar/releases/download/v${version}/LiquidBar-${version}.zip";
    hash = "sha256-rzDqFPpD7jYRdetwX4go70MZ2qlCYg723qZtPEJYp9k=";
  };

  nativeBuildInputs = [ unzip ];
  unpackPhase = ''
    runHook preUnpack
    # Zips up to 0.5.0 carry AppleDouble ._* files, which break the bundle's code signature.
    unzip -q "$src" -x '*/._*'
    runHook postUnpack
  '';
  # Accessibility is granted to the signature, so the bundle must stay byte-identical.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R LiquidBar.app "$out/Applications/"
    test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$out/Applications/LiquidBar.app/Contents/Info.plist")" = "${version}"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/LiquidBar.app"
    runHook postInstall
  '';

  meta = {
    description = "Liquid Glass menu bar replacement";
    homepage = "https://github.com/jbroma/liquid-bar";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
  };
}
