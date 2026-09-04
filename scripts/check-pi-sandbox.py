#!/usr/bin/env python3
"""Exercise project state, parallel network reservations, and fail-closed startup."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


source = Path(sys.argv[1] if len(sys.argv) > 1 else "scripts/pi-sandbox.sh").read_text()
with tempfile.TemporaryDirectory(prefix="pi-sandbox-check-") as directory:
    root = Path(directory)
    state = root / "networks"
    state.mkdir()
    cli = root / "container"
    cli.write_text('''#!/usr/bin/env python3
import json, os, shutil, sys, time
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["TEST_CALLS"], "a") as log:
    log.write(json.dumps(args) + "\\n")
state = Path(os.environ["TEST_NETWORK_STATE"])
if args[:2] == ["network", "create"]:
    if os.environ.get("TEST_CREATE_FAIL"):
        sys.exit(1)
    path = state / args[-1]
    try:
        path.mkdir()
    except FileExistsError:
        sys.exit(1)
    (path / "subnet").write_text(args[args.index("--subnet") + 1])
elif args[:2] == ["network", "inspect"]:
    path = state / args[-1] / "subnet"
    if not path.exists():
        sys.exit(1)
    print(json.dumps([{"configuration":{"mode":"hostOnly"},"status":{"ipv4Subnet":path.read_text()}}]))
elif args[:2] == ["network", "delete"]:
    shutil.rmtree(state / args[-1])
elif args[0] == "run":
    if os.environ.get("TEST_RUN_READY"):
        ready = Path(os.environ["TEST_RUN_READY"])
        temporary = ready.with_suffix(".tmp")
        temporary.write_text(json.dumps(args))
        temporary.replace(ready)
        while not Path(os.environ["TEST_RUN_RELEASE"]).exists():
            time.sleep(0.02)
    sys.exit(int(os.environ.get("TEST_RUN_EXIT", "0")))
''')
    cli.chmod(0o755)
    sudo = root / "sudo"
    sudo.write_text('#!/bin/sh\nexit "$TEST_FIREWALL_STATUS"\n')
    sudo.chmod(0o755)
    script = root / "launcher"
    script.write_text(source.replace("/usr/bin/sudo", str(sudo)))
    calls = root / "calls"
    pool = [
        {"name": f"llm-sandbox-{i}", "subnet": f"10.171.71.{i * 8}/29", "gateway": f"10.171.71.{i * 8 + 1}"}
        for i in range(2)
    ]
    pool_file = root / "networks.json"
    pool_file.write_text(json.dumps(pool))
    env = {
        **os.environ, "PATH": f"{root}:{os.environ['PATH']}", "TEST_CALLS": str(calls),
        "TEST_NETWORK_STATE": str(state), "TEST_FIREWALL_STATUS": "0",
        "SANDBOX_NETWORKS_FILE": str(pool_file),
        # The old launcher's inputs let this test demonstrate its failing-before behavior.
        "SANDBOX_NETWORK": "llm-sandbox", "SANDBOX_SUBNET": "10.171.71.0/24", "LLM_SERVER": "10.171.71.1",
        "LLM_PORT": "11434", "LLM_MODEL_DEFAULT": "test", "LLM_CONTEXT": "131072",
        "PI_SANDBOX_CONTEXT": "/nix/store/01234567890123456789012345678901-pi",
    }
    command = ["bash", "-euo", "pipefail", str(script)]

    def launch(project, changes=None, arguments=None):
        calls.write_text("")
        result = subprocess.run(
            [*command, *(arguments or ["-p", "hello"])], cwd=project,
            env={**env, **(changes or {})}, capture_output=True, text=True,
        )
        commands = [json.loads(line) for line in calls.read_text().splitlines()]
        return result, [args for args in commands if args[0] == "run"]

    first, second, alias = root / "first", root / "second", root / "alias"
    first.mkdir()
    second.mkdir()
    alias.symlink_to(first, target_is_directory=True)
    release = root / "release"
    processes, runs = [], []
    try:
        for index, project in enumerate((first, second)):
            ready = root / f"ready-{index}"
            process = subprocess.Popen(
                [*command, "-p", "hello"], cwd=project,
                env={**env, "TEST_RUN_READY": str(ready), "TEST_RUN_RELEASE": str(release)},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            processes.append(process)
            deadline = time.monotonic() + 5
            while not ready.exists():
                assert process.poll() is None, process.communicate()
                assert time.monotonic() < deadline, "parallel launch did not start"
                time.sleep(0.02)
            runs.append(json.loads(ready.read_text()))
        networks = [args[args.index("--network") + 1] for args in runs]
        assert len(set(networks)) == 2, "parallel sandboxes share a network"
        assert all(process.poll() is None for process in processes)
        for args, network in zip(runs, networks):
            gateway = next(item["gateway"] for item in pool if item["name"] == network)
            assert f"LLM_SERVER={gateway}" in args
        print("parallel sandboxes use separate networks and gateways: passed")
    finally:
        release.touch()
        for process in processes:
            process.communicate(timeout=5)
    assert all(process.returncode == 0 for process in processes)
    assert not list(state.iterdir()), "network reservations were not released"

    runs = []
    for project in (first, second, alias):
        result, commands = launch(project)
        assert result.returncode == 0, result.stderr
        assert len(commands) == 1, commands
        assert not list(state.iterdir())
        runs.append(commands[0])
    volumes = [args[args.index("--volume") + 1] for args in runs]
    assert volumes[0] != volumes[1], "different projects share Pi state"
    assert volumes[0] == volumes[2], "a symlink creates a different project identity"
    for args in runs:
        assert args[args.index("--kernel-arg") + 1] == "ipv6.disable=1"
        for capability in ("CAP_NET_RAW", "CAP_NET_ADMIN"):
            assert any(args[i:i + 2] == ["--cap-drop", capability] for i in range(len(args)))
    print("project state and reusable network reservations: passed")
    for changes, expected in (({"TEST_FIREWALL_STATUS": "1"}, 1), ({"TEST_RUN_EXIT": "23"}, 23), ({"TEST_CREATE_FAIL": "1"}, 1)):
        result, commands = launch(first, changes)
        assert result.returncode == expected, result.stderr
        if "TEST_RUN_EXIT" not in changes:
            assert not commands, "guest started after a preparation failure"
        assert not list(state.iterdir()), "failed launch left a network reservation"
    # Never reuse a pre-existing reservation, even if its owner's launcher is gone.
    for item in pool:
        (state / item["name"]).mkdir()
    result, commands = launch(first)
    assert result.returncode != 0 and not commands
    assert len(list(state.iterdir())) == len(pool)
    for path in state.iterdir():
        path.rmdir()
    print("startup failures and exhausted pool fail closed: passed")
    for override in (["--network", "other"], ["--network=other"], ["-d"], ["--detach"], ["--rm=false"]):
        result, commands = launch(first, arguments=[*override, "--", "-p", "hello"])
        assert result.returncode != 0 and not commands
    result, commands = launch(first, arguments=["--name", "custom-name", "--", "-p", "hello"])
    assert result.returncode == 0 and commands[0][commands[0].index("--name") + 1] == "custom-name"
    print("network ownership and custom container names: passed")
