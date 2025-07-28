{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  name = "cleanshot-x";
  version = "4.8.2";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${version}.dmg";
    sha256 = "c88819f112071ad7909ff5b7eb26d2c010eab33673ca0d47d117446bc3104526";
  };

  nativeBuildInputs = [ _7zz ];

  sourceRoot = ".";
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r "CleanShot X.app" "$out/Applications/CleanShot X.app"
  '';

  meta = with lib; {
    homepage = "https://cleanshot.com/";
    description = "Capture your Mac’s screen like a pro.";
    platforms = platforms.darwin;
  };
}
