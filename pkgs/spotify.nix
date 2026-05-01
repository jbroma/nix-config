{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

stdenvNoCC.mkDerivation {
  pname = "spotify";
  version = "1.2.88.483";

  src = fetchurl {
    url = "https://download.scdn.co/SpotifyARM64.dmg";
    hash = "sha256-rBoJ5PKge4pr90FqYwsG+6JqyKvc3sKyPXM7OXXEmz8=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R Spotify.app "$out/Applications/"

    runHook postInstall
  '';

  meta = {
    description = "Official Spotify macOS app";
    homepage = "https://www.spotify.com/";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
