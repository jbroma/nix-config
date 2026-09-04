#!/usr/bin/env python3
"""Harmless fixture checks for host-file safety. No containers or system policy changes."""

import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("agent_sandbox", Path(__file__).with_name("agent-sandbox.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeRunner(module.Runner):
    """Native resource operations are simulated; guest commands never execute on the host."""
    def __init__(self, directory):
        super().__init__({
            "stateDir": str(directory), "container": "container", "transferLimit": 1048576,
            "firewallCheck": "/fixture-check", "modelPort": None, "proxyPort": 11436,
            "networks": {profile: [
                {"name": f"{profile}-{slot}", "subnet": f"10.0.{slot}.0/29", "gateway": f"10.0.{slot}.1"}
                for slot in range(2)
            ] for profile in ("offline", "internet", "model")},
        })
        self.resources = {kind: set() for kind in ("network", "volume", "container")}
        self.calls = []
        self.inspect_error = False

    def container(self, *args, **kwargs):
        self.calls.append(args)
        if args[0] in ("network", "volume"):
            kind, operation = args[:2]
            name = args[-1]
        elif args[0] in ("inspect", "delete", "stop"):
            kind, operation, name = "container", args[0], args[-1]
        elif args[0] == "run":
            kind, operation, name = "container", "create", args[args.index("--name") + 1]
        else:
            return SimpleNamespace(returncode=0, stdout=b"", stderr=b"")
        if operation == "create":
            if name in self.resources[kind]:
                return SimpleNamespace(returncode=1, stdout=b"", stderr=b"exists")
            self.resources[kind].add(name)
        elif operation == "inspect":
            if self.inspect_error:
                return SimpleNamespace(returncode=1, stdout=b"", stderr=b"API unavailable")
            if name not in self.resources[kind]:
                return SimpleNamespace(returncode=1, stdout=b"", stderr=f"notFound: {name}".encode())
        elif operation == "delete":
            self.resources[kind].remove(name)
        return SimpleNamespace(returncode=0, stdout=b"", stderr=b"")


class HostSafety(unittest.TestCase):
    def test_image_options_and_existing_journals_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            args = SimpleNamespace(project=None, image="--mount=host", network="offline", env=[], cpus=2, memory="512M")
            with self.assertRaises(module.SandboxError):
                runner.create(args)
            self.assertFalse(runner.calls)
            args.image = "fixture"
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)), patch.object(module.uuid, "uuid4", return_value=SimpleNamespace(hex="a" * 32)):
                session = runner.create(args)
                before = runner.record_path(session).read_bytes()
                with self.assertRaises(FileExistsError):
                    runner.create(args)
                self.assertEqual(runner.record_path(session).read_bytes(), before)
                self.assertEqual(len(runner.resources["network"]), 1)
            runner.destroy(session)

    def test_snapshot_rejects_metadata_aliases_and_parent_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "project"
            project.mkdir()
            (project / "linked").symlink_to(root, target_is_directory=True)
            (root / "fixture.txt").write_text("outside fixture")
            with patch.object(module.subprocess, "check_output", return_value=b".GIT/config\0"):
                with self.assertRaises(module.SandboxError):
                    module.snapshot(project, io.BytesIO(), 1048576)
            with patch.object(module.subprocess, "check_output", return_value=b"linked/fixture.txt\0"):
                with self.assertRaises(OSError):
                    module.snapshot(project, io.BytesIO(), 1048576)

    def test_private_storage_parallel_reservations_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            args = SimpleNamespace(project=None, image="fixture", network="offline", env=[], cpus=2, memory="512M")
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                first = runner.create(args)
                second = runner.create(args)
                with self.assertRaises(module.SandboxError):
                    runner.create(args)
            self.assertNotEqual(runner.record(first)["network"], runner.record(second)["network"])
            for call in runner.calls:
                if call[0] == "run":
                    self.assertIn("--read-only", call)
                    self.assertEqual(call[call.index("--mount") + 1], "type=tmpfs,target=/tmp,size=256M")
                    self.assertFalse(any("type=bind" in str(value) for value in call))
                    self.assertNotIn("--ssh", call)
                    self.assertFalse(any("http_proxy=" in str(value) for value in call))
            runner.destroy(first)
            self.assertTrue(runner.record_path(second).exists())
            self.assertEqual(len(runner.resources["network"]), 1)
            runner.destroy(second)
            self.assertFalse(any(runner.resources.values()))

    def test_failed_guard_releases_resources_and_unavailable_api_keeps_journal(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            args = SimpleNamespace(project=None, image="fixture", network="offline", env=[], cpus=2, memory="512M")
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=1)):
                with self.assertRaises(module.SandboxError):
                    runner.create(args)
            self.assertFalse(any(runner.resources.values()))
            self.assertFalse(list(Path(directory).glob("asb-*.json")))
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                session = runner.create(args)
            runner.inspect_error = True
            with self.assertRaises(module.SandboxError):
                runner.destroy(session)
            self.assertTrue(runner.record_path(session).exists())

    def test_network_profiles_are_explicit(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            args = SimpleNamespace(project=None, image="fixture", network="model", env=[], cpus=2, memory="512M")
            with self.assertRaises(module.SandboxError):
                runner.create(args)
            args.network = "internet"
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                session = runner.create(args)
            call = next(call for call in runner.calls if call[0] == "run")
            self.assertIn("https_proxy=http://10.0.0.1:11436", call)
            runner.destroy(session)

    def test_snapshot_copies_working_files_without_following_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "project"
            project.mkdir()
            subprocess.run(["git", "init", "-q", str(project)], check=True)
            (project / ".gitignore").write_text("ignored.txt\n")
            (project / "source.txt").write_text("original fixture\n")
            (project / "ignored.txt").write_text("not part of the snapshot\n")
            (root / "outside.txt").write_text("outside fixture stays on host\n")
            (project / "link").symlink_to(root / "outside.txt")
            output = io.BytesIO()
            module.snapshot(project, output, 1024 * 1024)
            with tarfile.open(fileobj=output) as archive:
                self.assertEqual(set(archive.getnames()), {".gitignore", "source.txt", "link"})
                self.assertTrue(archive.getmember("link").issym())
                self.assertEqual(archive.extractfile("source.txt").read(), b"original fixture\n")
            self.assertEqual((root / "outside.txt").read_text(), "outside fixture stays on host\n")
            self.assertEqual((project / "source.txt").read_text(), "original fixture\n")
            with self.assertRaises(module.SandboxError):
                module.snapshot(project, io.BytesIO(), 8)

    def test_export_saves_bytes_without_extracting_or_overwriting_host_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root / "outside.txt"
            outside.write_text("unchanged")
            session = "asb-" + "a" * 32
            runner = module.Runner({"stateDir": str(root / "state"), "container": "container", "transferLimit": 1024 * 1024, "networks": {"offline": [{"name": "test-network"}]}})
            runner.record_path(session).write_text(json.dumps({"network": "test-network"}))
            payload = io.BytesIO()
            with tarfile.open(fileobj=payload, mode="w") as archive:
                member = tarfile.TarInfo("../../outside.txt")
                member.size = 7
                archive.addfile(member, io.BytesIO(b"fixture"))
            process = SimpleNamespace(stdout=io.BytesIO(payload.getvalue()), wait=lambda **kwargs: 0)
            with patch.object(module.subprocess, "Popen", return_value=process):
                exported = runner.export(SimpleNamespace(session=session, path="."))
            self.assertEqual(exported.read_bytes(), payload.getvalue())
            self.assertEqual(outside.read_text(), "unchanged")
            with self.assertRaises(module.SandboxError):
                runner.export(SimpleNamespace(session=session, path="../outside.txt"))
            with self.assertRaises(module.SandboxError):
                runner.record_path("../../outside.txt")


if __name__ == "__main__":
    unittest.main()
