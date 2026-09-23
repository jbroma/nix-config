# Lists every launchd agent/daemon and login item macOS tracks in
# System Settings > General > Login Items, with the command it really runs
# and who signed that binary. Settings shows only the executable name, so every
# `/bin/sh -c ...` wrapper (nix-darwin, home-manager) appears there as "sh".

# Prints the signer of a binary or bundle: the first Developer ID / Apple
# authority, "ad-hoc" for local signatures (Nix builds), or "UNSIGNED".
signer() {
  local info
  [[ -e $1 ]] || { echo "MISSING"; return; }
  info=$(codesign -dvv "$1" 2>&1) || { echo "UNSIGNED"; return; }
  if grep -q '^Authority=' <<<"$info"; then
    grep -m1 '^Authority=' <<<"$info" | cut -d= -f2-
  else
    echo "ad-hoc"
  fi
}

# Prints the binary a launchd plist runs, then its full command line.
# Unwraps nix-darwin's `sh -c "/bin/wait4path /nix/store && exec X"`.
plist_command() {
  local args cmd target
  args=$(plutil -convert json -o - "$1" 2>/dev/null | jq -c '.ProgramArguments // [.Program]') || return 1
  target=$(jq -r '.[0]' <<<"$args")
  if [[ $(jq -r '.[0:2] | join(" ")' <<<"$args") == "/bin/sh -c" ]]; then
    cmd=$(jq -r '.[2]' <<<"$args")
    cmd=${cmd#/bin/wait4path * && }
    cmd=${cmd#exec }
    target=${cmd%% *}
  else
    cmd=$(jq -r 'join(" ")' <<<"$args")
  fi
  printf '%s\n%s\n' "$target" "$cmd"
}

report() {
  local type=$1 label=$2 url=$3 exe=$4 path cmd target
  path=$(printf '%b' "${url#file://}")
  path=${path//%20/ }
  if [[ $path != *.plist ]]; then
    cmd=$path target=$path
  elif [[ ! -e $path ]]; then
    printf '%s\n  %s  (stale: plist gone)\n\n' "$label" "$type"
    return
  elif ! { read -r target; read -r cmd; } < <(plist_command "$path"); then
    # Root-only plist: fall back to the executable Background Task Management recorded.
    cmd="$exe (plist unreadable)" target=$exe
  fi
  printf '%s\n  %s  %s\n  runs:   %s\n  signed: %s\n\n' "$label" "$type" "$path" "$cmd" "$(signer "$target")"
}

# One "type<TAB>identifier<TAB>url<TAB>executable" line per item that runs code; "app" and
# "developer" records are only the group headers Settings shows.
sfltool dumpbtm 2>/dev/null |
  awk -v uid="$(id -u)" '
    /Records for UID/ { mine = ($4 == uid || $4 == "-2") }
    /^ +Type:/        { sub(/^ +Type: /, ""); sub(/ \(0x.*/, ""); type = $0 }
    /^ +Identifier:/  { sub(/^ +Identifier: /, ""); id = $0 }
    /^ +#[0-9]+:/     { exe = "" }
    /^ +URL:/         { sub(/^ +URL: /, ""); url = $0 }
    /Executable Path:/ { sub(/^ +Executable Path: /, ""); exe = $0 }
    /^ +Generation:/  {
      if (mine && url ~ /^file:/ && type !~ /^(app|developer)$/) print type "\t" id "\t" url "\t" exe
    }' |
  sort -u |
  while IFS=$'\t' read -r type id url exe; do
    report "$type" "${id#*.}" "$url" "$exe"
  done
