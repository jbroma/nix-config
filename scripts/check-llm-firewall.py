#!/usr/bin/env python3
"""Test the built firewall startup script without touching the host firewall.

Run with `mise run check-llm-firewall`. Only pfctl is replaced with a test command.
"""

import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


daemon = json.loads(subprocess.check_output([
    "nix", "eval", "--json", "--option", "eval-cache", "false",
    ".#darwinConfigurations.personal-llm-server.config.launchd.daemons.llm-sandbox-pf",
], text=True))
source = Path(daemon["command"]).read_text()
assert source.count("/sbin/pfctl") == 3, "review test substitution when startup changes"
system_path = subprocess.check_output([
    "nix", "eval", "--raw", "--option", "eval-cache", "false",
    ".#darwinConfigurations.personal-llm-server.config.system.path",
], text=True)
check_source = (Path(system_path) / "bin/llm-sandbox-check").read_text()

with tempfile.TemporaryDirectory(prefix="llm-firewall-check-") as directory:
    root = Path(directory)
    stub = root / "pfctl"
    stub.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$PF_TEST_CALLS"
case " $* " in
  *" -f "*) exit "$PF_TEST_LOAD_STATUS" ;;
  *" -E "*) exit "$PF_TEST_ENABLE_STATUS" ;;
  *" -a "*) printf '%s\\n' "$PF_TEST_RULES"; exit "$PF_TEST_READ_STATUS" ;;
  *" -s info "*) printf '%s\\n' "$PF_TEST_STATUS" ;;
  *" -sr "*) printf '%s\\n' "$PF_TEST_MAIN" ;;
  *) exit 99 ;;
esac
''')
    stub.chmod(0o755)
    script = root / "startup"
    def substitute(text):
        return text.replace("/sbin/pfctl", shlex.quote(str(stub))).replace(
            "/var/run/llm-sandbox-pf", str(root / "snapshot"),
        )

    script.write_text(substitute(source))
    script.chmod(0o755)
    calls = root / "calls"
    env = {
        **os.environ, "PF_TEST_CALLS": str(calls), "PF_TEST_LOAD_STATUS": "0",
        "PF_TEST_ENABLE_STATUS": "0", "PF_TEST_READ_STATUS": "0",
        "PF_TEST_RULES": "block drop in quick inet from 10.171.71.0/24 to any",
        "PF_TEST_STATUS": "Status: Enabled for 0 days", "PF_TEST_MAIN": 'anchor "com.apple/*" all',
    }
    for name, changes, expected_exit, expected_calls in (
        ("rule load fails", {"PF_TEST_LOAD_STATUS": "23"}, 23, 1),
        ("rule read fails", {"PF_TEST_READ_STATUS": "31"}, 31, 2),
        ("empty rules", {"PF_TEST_RULES": ""}, 1, 2),
        ("enable fails", {"PF_TEST_ENABLE_STATUS": "29"}, 29, 3),
        ("startup succeeds", {}, 0, 3),
    ):
        calls.write_text("")
        result = subprocess.run([str(script)], env={**env, **changes})
        assert result.returncode == expected_exit, (name, result.returncode, expected_exit)
        assert len(calls.read_text().splitlines()) == expected_calls, (name, calls.read_text())
        print(f"{name}: passed")

    checker = root / "checker"
    checker.write_text(substitute(check_source))
    checker.chmod(0o755)
    for name, changes, expected in (
        ("active protection", {}, 0),
        ("pf disabled", {"PF_TEST_STATUS": "Status: Disabled"}, 1),
        ("main anchor missing", {"PF_TEST_MAIN": ""}, 1),
        ("sandbox anchor empty", {"PF_TEST_RULES": ""}, 1),
        ("sandbox rules changed", {"PF_TEST_RULES": "pass all"}, 1),
        ("pf read failed", {"PF_TEST_READ_STATUS": "31"}, 31),
    ):
        calls.write_text("")
        result = subprocess.run([str(checker)], env={**env, **changes}, capture_output=True, text=True)
        assert result.returncode == expected, (name, result.returncode, result.stderr)
        assert all(" -f " not in line and " -E" not in line for line in calls.read_text().splitlines())
        print(f"checker {name}: passed")
    snapshot = root / "snapshot.rules"
    assert snapshot.stat().st_mode & 0o777 == 0o600
    snapshot.write_text("old configuration\n" + env["PF_TEST_RULES"] + "\n")
    assert subprocess.run([str(checker)], env=env, capture_output=True).returncode == 1
    snapshot.unlink()
    assert subprocess.run([str(checker)], env=env, capture_output=True).returncode == 1
    assert subprocess.run([str(checker), "unexpected-argument"], env=env, capture_output=True).returncode == 1
    print("checker stale/missing snapshot and unexpected arguments: passed")

service = daemon["serviceConfig"]
assert service["RunAtLoad"] is True
# nix-darwin omits null option defaults when it writes the plist.
keep_alive = {key: value for key, value in service["KeepAlive"].items() if value is not None}
assert keep_alive == {"SuccessfulExit": False}, "retry failures, stop after success"
assert service["ThrottleInterval"] >= 5, "avoid a tight retry loop"
print("launchd retry policy: passed")
