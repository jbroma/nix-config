#!/usr/bin/env python3
"""Optional post-activation smoke test. Only temporary fixture files are edited."""

import subprocess
import tarfile
import tempfile
from pathlib import Path


def command(*args):
    return subprocess.check_output(["agent-sandbox", *args], text=True).strip()


sessions = []
try:
    with tempfile.TemporaryDirectory(prefix="agent-sandbox-fixture-") as directory:
        project = Path(directory)
        subprocess.run(["git", "init", "-q", str(project)], check=True)
        (project / "fixture.txt").write_text("original fixture\n")
        for _ in range(2):
            sessions.append(command("create", "--project", directory, "--cpus", "1", "--memory", "512M"))
        command("exec", sessions[0], "--", "python3", "-c", "from pathlib import Path; p=Path('/workspace/fixture.txt'); p.write_text(p.read_text()+'guest edit\\n')")
        assert command("exec", sessions[1], "--", "cat", "/workspace/fixture.txt") == "original fixture"
        assert (project / "fixture.txt").read_text() == "original fixture\n"
        exported = command("export", sessions[0], "--path", "fixture.txt")
        with tarfile.open(exported) as archive:
            assert archive.extractfile("fixture.txt").read() == b"original fixture\nguest edit\n"
        print("Separate private workspaces, repeated commands, and export passed. Host fixture unchanged.")
        print(f"Fixture archive retained for inspection: {exported}")
finally:
    failed = []
    for session in sessions:
        if subprocess.run(["agent-sandbox", "destroy", session]).returncode:
            failed.append(session)
    if failed:
        raise RuntimeError("Retry cleanup for fixture sandboxes: " + ", ".join(failed))
