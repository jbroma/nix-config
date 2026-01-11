{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation rec {
  name = "claude-island";
  version = "1.2";

  src = fetchurl {
    url = "https://github.com/farouqaldori/claude-island/releases/download/v${version}/ClaudeIsland-${version}.dmg";
    sha256 = "18ira668jw1xyasqx2zjrvhhk3j5l0nfxblirwsd1gvx88xy57m2";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r "Claude Island.app" "$out/Applications/Claude Island.app"
  '';

  meta = with lib; {
    homepage = "https://github.com/farouqaldori/claude-island";
    description = "A menu bar app that lets you access Claude in a floating window";
    platforms = platforms.darwin;
    license = licenses.mit;
  };
}
