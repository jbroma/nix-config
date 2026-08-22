#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ca="$repo_root/homelab-ca.crt"
scan_seconds=${OPENDROP_SCAN_SECONDS:-12}

if [ ! -f "$ca" ]; then
  echo "Missing CA certificate: $ca" >&2
  exit 1
fi

if ! command -v opendrop >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Missing dependency: opendrop

Apply the personal Nix configuration so the custom opendrop package is on PATH,
then rerun:
  darwin-rebuild-switch
EOF
  exit 1
fi

if ! command -v fzf >/dev/null 2>&1; then
  echo "Missing dependency: fzf" >&2
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/homelab-ca-airdrop.XXXXXX")
find_log="$tmp_dir/opendrop-find.log"
receivers="$tmp_dir/receivers.tsv"

stop_find() {
  if [ "${find_pid:-}" ]; then
    kill -INT "$find_pid" >/dev/null 2>&1 || true
    tries=0
    while kill -0 "$find_pid" >/dev/null 2>&1; do
      tries=$((tries + 1))
      if [ "$tries" -ge 10 ]; then
        kill -TERM "$find_pid" >/dev/null 2>&1 || true
        break
      fi
      sleep 0.2
    done
    wait "$find_pid" >/dev/null 2>&1 || true
    find_pid=
  fi
}

cleanup() {
  stop_find
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

echo "Scanning for AirDrop receivers for ${scan_seconds}s..."
/usr/bin/open "airdrop:" >/dev/null 2>&1 || true
opendrop find >"$find_log" 2>&1 &
find_pid=$!
sleep "$scan_seconds"
stop_find

awk '
  /^Found[[:space:]]+index[[:space:]]+[0-9]+[[:space:]]+ID[[:space:]]+/ {
    id = $5
    name = ""
    for (i = 7; i <= NF; i++) {
      name = name (name ? " " : "") $i
    }
    if (!seen[id]++) {
      print id "\t" name
    }
  }
' "$find_log" >"$receivers"

if [ ! -s "$receivers" ]; then
  cat >&2 <<EOF
No AirDrop receivers found.

OpenDrop output:
$(cat "$find_log")

On the iPhone, make sure AirDrop is visible and try again:
  OPENDROP_SCAN_SECONDS=20 mise run ca
EOF
  exit 1
fi

selected=$(
  fzf \
    --prompt="AirDrop target> " \
    --delimiter="$(printf '\t')" \
    --with-nth=2,1 \
    --header="Select the iPhone to receive homelab-ca.crt" \
    <"$receivers" || true
)

if [ -z "$selected" ]; then
  echo "No AirDrop target selected." >&2
  exit 1
fi

receiver_id=${selected%%	*}
receiver_name=${selected#*	}

echo "Sending homelab-ca.crt to $receiver_name ($receiver_id)..."
opendrop send -r "$receiver_id" -f "$ca"

cat <<'EOF'
Sent. On the iPhone:
1. Accept the AirDrop. Do not choose "Save to Files"; tap the downloaded profile
   notification, or open Settings -> General -> VPN & Device Management and
   install the "Orion Homelab CA" profile.
2. Open Settings -> General -> About -> Certificate Trust Settings and enable
   full trust for "Orion Homelab CA".

EOF
