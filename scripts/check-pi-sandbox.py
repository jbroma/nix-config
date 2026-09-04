#!/usr/bin/env python3
"""Check launcher isolation with a fake container CLI and firewall checker."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


source = Path("scripts/pi-sandbox.sh").read_text()
with tempfile.TemporaryDirectory(prefix="pi-sandbox-check-") as directory:
    root = Path(directory)
    cli = root / "container"
    cli.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
if sys.argv[1:3] == ["network", "inspect"]:
    print('[{"configuration":{"mode":"hostOnly"},"status":{"ipv4Subnet":"10.171.71.0/24"}}]')
''')
    cli.chmod(0o755)
    sudo = root / "sudo"
    sudo.write_text('#!/bin/sh\nexit "$TEST_FIREWALL_STATUS"\n')
    sudo.chmod(0o755)
    script = root / "launcher"
    script.write_text(source.replace("/usr/bin/sudo", str(sudo)))
    calls = root / "calls"
    env = {
        **os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_CALLS": str(calls),
        "TEST_FIREWALL_STATUS": "0", "SANDBOX_NETWORK": "llm-sandbox",
        "SANDBOX_SUBNET": "10.171.71.0/24", "LLM_SERVER": "10.171.71.1",
        "LLM_PORT": "11434", "LLM_MODEL_DEFAULT": "test", "LLM_CONTEXT": "131072",
        "PI_SANDBOX_CONTEXT": "/nix/store/01234567890123456789012345678901-pi",
    }

    def launch(project, firewall_status="0"):
        calls.write_text("")
        result = subprocess.run(
            ["bash", "-euo", "pipefail", str(script), "-p", "hello"], cwd=project,
            env={**env, "TEST_FIREWALL_STATUS": firewall_status}, capture_output=True, text=True,
        )
        commands = [json.loads(line) for line in calls.read_text().splitlines()]
        return result, [args for args in commands if args[0] == "run"]

    first, second, alias = root / "first", root / "second", root / "alias"
    first.mkdir()
    second.mkdir()
    alias.symlink_to(first, target_is_directory=True)
    runs = []
    for project in (first, second, alias):
        result, commands = launch(project)
        assert result.returncode == 0, result.stderr
        assert len(commands) == 1, commands
        runs.append(commands[0])
    volumes = [args[args.index("--volume") + 1] for args in runs]
    assert volumes[0] != volumes[1], "different projects share Pi state"
    assert volumes[0] == volumes[2], "a symlink creates a different project identity"
    assert all(volume != "pi-sandbox-home:/root/.pi" for volume in volumes)
    for args in runs:
        assert args[args.index("--kernel-arg") + 1] == "ipv6.disable=1"
        for capability in ("CAP_NET_RAW", "CAP_NET_ADMIN"):
            assert any(args[i:i + 2] == ["--cap-drop", capability] for i in range(len(args)))
    print("project state and network restrictions: passed")
    result, commands = launch(first, "1")
    assert result.returncode != 0 and not commands, "container started without firewall protection"
    print("firewall failure blocks launch: passed")
