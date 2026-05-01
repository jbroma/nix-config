{ lib, ... }:

{
  home.activation.disableSpotifyUpdates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    spotify_update_dir="$HOME/Library/Application Support/Spotify/PersistentCache/Update"

    if ! /usr/bin/stat -f "%Sf" "$spotify_update_dir" 2>/dev/null | /usr/bin/grep -q uchg; then
      if [ -e "$spotify_update_dir" ]; then
        /usr/bin/chflags -R nouchg "$spotify_update_dir" 2>/dev/null || true
        /bin/rm -rf "$spotify_update_dir"
      fi

      /bin/mkdir -p "$spotify_update_dir"
      /usr/bin/chflags uchg "$spotify_update_dir"
    fi
  '';
}
