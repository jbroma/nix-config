{
  lib,
  stdenvNoCC,
  fetchurl,
  writeShellApplication,
}:

let
  version = "1.2.84.476";

  dmg = fetchurl {
    url = "https://web.archive.org/web/20260228212834/https://download.scdn.co/SpotifyARM64.dmg";
    hash = "sha256-Zj5qATaW1QPTInC/Y/jZx2xq5eHG/OQixpj8DWUpEXY=";
  };

  installer = writeShellApplication {
    name = "install-spotify";
    text = ''
      set -euo pipefail

      target="''${1:-/Applications/Spotify.app}"
      expected_version="${version}"
      dmg="${dmg}"

      current_version=""
      if [ -f "$target/Contents/Info.plist" ]; then
        current_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$target/Contents/Info.plist" 2>/dev/null || true)
      fi

      verify_spotify_sig_xattrs() {
        app="$1"
        sig_file="$app/Contents/MacOS/Spotify.sig"

        for attr in \
          com.apple.cs.CodeDirectory \
          com.apple.cs.CodeRequirements \
          com.apple.cs.CodeRequirements-1 \
          com.apple.cs.CodeSignature; do
          if ! /usr/bin/xattr -p "$attr" "$sig_file" >/dev/null; then
            echo "Missing $attr on $sig_file" >&2
            return 1
          fi
        done
      }

      if [ "$current_version" = "$expected_version" ] \
        && /usr/bin/codesign --verify --deep --strict "$target" >/dev/null 2>&1 \
        && /usr/sbin/spctl --assess --type execute "$target" >/dev/null 2>&1 \
        && verify_spotify_sig_xattrs "$target"; then
        exit 0
      fi

      tmp_dir=$(/usr/bin/mktemp -d "''${TMPDIR:-/tmp}/spotify-install.XXXXXX")
      mount_dir="$tmp_dir/mount"
      staged_app="$tmp_dir/Spotify.app"

      cleanup() {
        /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
        /bin/rm -rf "$tmp_dir"
      }
      trap cleanup EXIT

      /bin/mkdir -p "$mount_dir"

      echo "Installing Spotify $expected_version to $target"
      /usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg" >/dev/null
      /usr/bin/ditto --rsrc --extattr "$mount_dir/Spotify.app" "$staged_app"

      actual_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$staged_app/Contents/Info.plist")
      if [ "$actual_version" != "$expected_version" ]; then
        echo "Spotify version mismatch: expected $expected_version, got $actual_version" >&2
        exit 1
      fi

      verify_spotify_sig_xattrs "$staged_app"
      /usr/bin/codesign --verify --deep --strict "$staged_app" >/dev/null
      /usr/sbin/spctl --assess --type execute "$staged_app" >/dev/null

      /bin/mkdir -p "$(/usr/bin/dirname "$target")"
      /bin/rm -rf "$target"
      /usr/bin/ditto --rsrc --extattr "$staged_app" "$target"

      verify_spotify_sig_xattrs "$target"
      /usr/bin/codesign --verify --deep --strict "$target" >/dev/null
      /usr/sbin/spctl --assess --type execute "$target" >/dev/null
    '';
  };
in
stdenvNoCC.mkDerivation {
  pname = "spotify";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/spotify"
    ln -s "${installer}/bin/install-spotify" "$out/bin/install-spotify"
    ln -s "${dmg}" "$out/share/spotify/SpotifyARM64.dmg"

    runHook postInstall
  '';

  passthru = {
    inherit dmg installer;
  };

  meta = {
    description = "Nix-managed installer for the official Spotify macOS app";
    homepage = "https://www.spotify.com/";
    license = lib.licenses.unfree;
    mainProgram = "install-spotify";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
