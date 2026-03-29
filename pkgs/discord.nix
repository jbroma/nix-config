{
  stdenv,
  lib,
  fetchurl,
  undmg,
  makeWrapper,
  python3,
  writeTextFile,
  writeShellApplication,
  curl,
  git,
  jq,
  nix,
  perl,
  ripgrep,
}:

let
  version = "0.0.382";
  disableBreakingUpdates = writeTextFile {
    name = "disable-breaking-updates.py";
    executable = true;
    text = ''
      #!${python3}/bin/python3
      import json
      import os
      from pathlib import Path

      config_home = os.path.join(os.path.expanduser("~"), "Library", "Application Support")
      settings_path = Path(f"{config_home}/discord/settings.json")
      settings_path_temp = Path(f"{config_home}/discord/settings.json.tmp")

      if os.path.exists(settings_path):
          with settings_path.open(encoding="utf-8") as settings_file:
              try:
                  settings = json.load(settings_file)
              except json.JSONDecodeError:
                  print("[Nix] settings.json is malformed, letting Discord fix itself")
                  raise SystemExit(0)
      else:
          settings = {}

      if settings.get("SKIP_HOST_UPDATE"):
          print("[Nix] Disabling updates already done")
          raise SystemExit(0)

      settings["SKIP_HOST_UPDATE"] = True
      os.makedirs(settings_path.parent, exist_ok=True)
      with settings_path_temp.open("w", encoding="utf-8") as settings_file_temp:
          json.dump(settings, settings_file_temp, indent=2)
      settings_path_temp.rename(settings_path)
      print("[Nix] Disabled updates")
    '';
  };
in
stdenv.mkDerivation {
  pname = "discord";
  inherit version;

  src = fetchurl {
    # Source: nixpkgs pkgs/applications/networking/instant-messengers/discord/sources.json
    url = "https://stable.dl2.discordapp.net/apps/osx/${version}/Discord.dmg";
    hash = "sha256-vBadXUHrYhvkqzkCvGnKf25A19TKcFs5D0tzC54E0Hk=";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    cp -r "Discord.app" "$out/Applications/Discord.app"

    makeWrapper "$out/Applications/Discord.app/Contents/MacOS/Discord" "$out/bin/discord" \
      --run "${disableBreakingUpdates}"

    runHook postInstall
  '';

  meta = {
    description = "All-in-one cross-platform voice and text chat";
    downloadPage = "https://discord.com/download";
    homepage = "https://discord.com/";
    license = lib.licenses.unfree;
    mainProgram = "discord";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  passthru.updateScript = writeShellApplication {
    name = "update-discord";
    runtimeInputs = [
      curl
      git
      jq
      nix
      perl
      ripgrep
    ];
    text = builtins.readFile ../scripts/update-discord.sh;
  };
}
