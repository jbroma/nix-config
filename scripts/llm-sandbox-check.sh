# Invoked through sudo with no arguments. All paths and the anchor are fixed by Nix.
fail() { echo "llm-sandbox-check: $*" >&2; exit 1; }
[ "$#" -eq 0 ] || fail "arguments are not accepted"
[ -s "$PF_SNAPSHOT" ] || fail "firewall startup has not recorded its rules"
status=$(/sbin/pfctl -s info)
case $status in
  "Status: Enabled"*) ;;
  *) fail "pf is disabled" ;;
esac
# An anchor can contain rules without the main ruleset ever evaluating them.
main=$(/sbin/pfctl -sr)
printf '%s\n' "$main" | grep -Fxq 'anchor "com.apple/*" all' \
  || fail "the main ruleset does not evaluate the sandbox anchor"
active=$(/sbin/pfctl -a "$PF_ANCHOR" -sr)
[ -n "$active" ] || fail "sandbox rules are missing"
[ "$(< "$PF_SNAPSHOT")" = "$(printf '%s\n%s\n' "$PF_RULES" "$active")" ] \
  || fail "sandbox rules are stale or have changed since startup"
