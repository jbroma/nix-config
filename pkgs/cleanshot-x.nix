{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  name = "cleanshot-x";
  version = "4.8.7";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${version}.dmg";
    sha256 = "f2c58b691777e6acb1ba766e57195892634c1c3bbf79048a3d94cc4d5d8402ba";
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
