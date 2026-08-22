#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ca="$repo_root/homelab-ca.crt"

if [ ! -f "$ca" ]; then
  echo "Missing CA certificate: $ca" >&2
  exit 1
fi

if [ ! -x /usr/bin/swiftc ]; then
  cat >&2 <<'EOF'
Missing dependency: /usr/bin/swiftc

Install Apple's command line tools, then rerun:
  xcode-select --install
EOF
  exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/homelab-ca-airdrop.XXXXXX")
swift_file="$tmp_dir/AirDropShare.swift"
swift_bin="$tmp_dir/airdrop-share"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

cat >"$swift_file" <<'SWIFT'
import AppKit
import Darwin

final class Delegate: NSObject, NSSharingServiceDelegate {
  var status: Int32 = 0

  func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
    print("AirDrop share completed")
    status = 0
    NSApplication.shared.stop(nil)
  }

  func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
    fputs("AirDrop share failed: \(error.localizedDescription)\n", stderr)
    status = 1
    NSApplication.shared.stop(nil)
  }
}

let path = CommandLine.arguments[1]

guard FileManager.default.fileExists(atPath: path) else {
  fputs("File does not exist: \(path)\n", stderr)
  exit(1)
}

guard let service = NSSharingService(named: .sendViaAirDrop) else {
  fputs("AirDrop sharing service is unavailable\n", stderr)
  exit(2)
}

let app = NSApplication.shared
let delegate = Delegate()
let url = URL(fileURLWithPath: path)

app.setActivationPolicy(.regular)
service.delegate = delegate

Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
  fputs("AirDrop share timed out after 300 seconds\n", stderr)
  delegate.status = 124
  NSApplication.shared.stop(nil)
}

app.activate(ignoringOtherApps: true)
service.perform(withItems: [url])
app.run()
exit(delegate.status)
SWIFT

echo "Opening native AirDrop picker for homelab-ca.crt..."
/usr/bin/swiftc "$swift_file" -o "$swift_bin"
"$swift_bin" "$ca"

cat <<'EOF'
Sent. On the iPhone:
1. Accept the AirDrop. Do not choose "Save to Files"; tap the downloaded profile
   notification, or open Settings -> General -> VPN & Device Management and
   install the "Orion Homelab CA" profile.
2. Open Settings -> General -> About -> Certificate Trust Settings and enable
   full trust for "Orion Homelab CA".

EOF
