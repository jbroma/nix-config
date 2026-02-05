# OpenAI Codex - AI coding agent desktop app
# https://developers.openai.com/codex
{
  stdenv,
  lib,
  fetchurl,
  undmg,
}:

stdenv.mkDerivation {
  pname = "codex-app";
  version = "1.0.0";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg";
    hash = "sha256-xV0eQhiusgZU1Mv3XGH3C9merdaXelHXMwe6g8sYq0U=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -r "Codex.app" "$out/Applications/Codex.app"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI's coding agent desktop app for macOS";
    homepage = "https://openai.com/index/introducing-codex";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
  };
}
