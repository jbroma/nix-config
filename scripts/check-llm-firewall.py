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
assert source.count("/sbin/pfctl") == 2, "review test substitution when startup changes"

with tempfile.TemporaryDirectory(prefix="llm-firewall-check-") as directory:
    root = Path(directory)
    stub = root / "pfctl"
    stub.write_text('''#!/bin/sh
printf '%s\\n' "$*" >> "$PF_TEST_CALLS"
case " $* " in
  *" -f "*) exit "$PF_TEST_LOAD_STATUS" ;;
  *" -E "*) exit "$PF_TEST_ENABLE_STATUS" ;;
  *) exit 99 ;;
esac
''')
    stub.chmod(0o755)
    script = root / "startup"
    script.write_text(source.replace("/sbin/pfctl", shlex.quote(str(stub))))
    script.chmod(0o755)
    calls = root / "calls"
    for name, load_status, enable_status, expected_exit, expected_calls in (
        ("rule load fails", 23, 0, 23, 1),
        ("enable fails", 0, 29, 29, 2),
        ("startup succeeds", 0, 0, 0, 2),
    ):
        calls.write_text("")
        result = subprocess.run([str(script)], env={
            **os.environ,
            "PF_TEST_CALLS": str(calls),
            "PF_TEST_LOAD_STATUS": str(load_status),
            "PF_TEST_ENABLE_STATUS": str(enable_status),
        })
        assert result.returncode == expected_exit, (name, result.returncode, expected_exit)
        assert len(calls.read_text().splitlines()) == expected_calls, (name, calls.read_text())
        print(f"{name}: passed")

service = daemon["serviceConfig"]
assert service["RunAtLoad"] is True
# nix-darwin omits null option defaults when it writes the plist.
keep_alive = {key: value for key, value in service["KeepAlive"].items() if value is not None}
assert keep_alive == {"SuccessfulExit": False}, "retry failures, stop after success"
assert service["ThrottleInterval"] >= 5, "avoid a tight retry loop"
print("launchd retry policy: passed")
