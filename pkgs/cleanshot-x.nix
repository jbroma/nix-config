{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  name = "cleanshot-x";
  version = "4.8.5";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${version}.dmg";
    sha256 = "b734f910620d6a18e1f197fabbf22649247b38e17db482a46039233bf60a544e";
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
