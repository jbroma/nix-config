# Invoked through sudo with no arguments. All paths and the anchor are fixed by Nix.
fail() { echo "agent-sandbox-check: $*" >&2; exit 1; }
[ "$#" -eq 0 ] || fail "arguments are not accepted"
[ -s "$PF_SNAPSHOT" ] || fail "firewall startup has not recorded its rules"
status=$(/sbin/pfctl -s info)
case $status in
  "Status: Enabled"*) ;;
  *) fail "pf is disabled" ;;
esac
# Our dispatcher must be the first filtering rule. Scrub rules only normalize packets.
# Later rules, including Internet Sharing, cannot override our matching quick rules.
main=$(/sbin/pfctl -sr)
main=$(printf '%s\n' "$main" | grep -Ev '^($|scrub(-anchor)? )' || true)
[ "${main%%$'\n'*}" = 'anchor "com.apple/*" all' ] \
  || fail "filter rules before the sandbox dispatcher could bypass protection"
# Wildcard children execute alphabetically. No sibling may run before our quick rules.
anchors=$(/sbin/pfctl -a com.apple -s Anchors)
read -r first_anchor _ <<< "$(printf '%s\n' "$anchors" | LC_ALL=C /usr/bin/sort)"
[ "${first_anchor#com.apple/}" = "${PF_ANCHOR#com.apple/}" ] \
  || fail "sandbox anchor is not first in the main dispatcher"
active=$(/sbin/pfctl -a "$PF_ANCHOR" -sr)
[ -n "$active" ] || fail "sandbox rules are missing"
[ "$(< "$PF_SNAPSHOT")" = "$(printf '%s\n%s\n' "$PF_RULES" "$active")" ] \
  || fail "sandbox rules are stale or have changed since startup"
