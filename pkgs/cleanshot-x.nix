{
  stdenv,
  lib,
  fetchurl,
  _7zz,
}:

stdenv.mkDerivation rec {
  name = "cleanshot-x";
  version = "4.8.8";

  src = fetchurl {
    url = "https://updates.getcleanshot.com/v3/CleanShot-X-${version}.dmg";
    sha256 = "dddd72482120856ba6a2984159aacab47ca221be18cb9467867a4f3ba1cdd8a0";
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
