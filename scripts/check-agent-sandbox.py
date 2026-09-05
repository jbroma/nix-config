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
import threading
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch


sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("agent_sandbox", Path(__file__).with_name("agent-sandbox.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
REAL_POPEN = subprocess.Popen


def fixture_process(code):
    # Only small, locally-created fixture processes are started or terminated by these tests.
    return REAL_POPEN([sys.executable, "-c", code], stdout=subprocess.PIPE)


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
    def test_status_reads_metrics_without_mutation_or_private_environment_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state"
            state.mkdir(mode=0o755)
            state.chmod(0o755)
            session = "asb-" + "a" * 32
            record = state / f"{session}.json"
            record.write_text(json.dumps({"network": "offline-0", "mode": "offline"}))
            runner = module.Runner({"stateDir": str(state), "container": "container", "networks": {"offline": [{"name": "offline-0"}]}}, initialize_state=False)
            samples = iter([1000000, 1500000])
            calls = []
            def container(*args, **kwargs):
                calls.append(args)
                if args[0] == "list":
                    data = [{"id": session, "status": {"state": "running"}, "configuration": {"initProcess": {"environment": ["PRIVATE_FIXTURE=do-not-emit"]}}}]
                elif args[0] == "stats":
                    data = [{"id": session, "cpuUsageUsec": next(samples), "memoryUsageBytes": 67108864, "memoryLimitBytes": 536870912}]
                else:
                    data = {"images": {"total": 2, "active": 1, "sizeInBytes": 4096, "reclaimable": 1024}}
                return SimpleNamespace(returncode=0, stdout=json.dumps(data).encode())
            with patch.object(runner, "container", side_effect=container), patch.object(module.time, "sleep"), patch.object(module.time, "monotonic", side_effect=[10, 11]), patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout="1")):
                result = runner.status()
            self.assertEqual(result["sessions"][0]["cpuPercent"], 50.0)
            self.assertEqual(result["sessions"][0]["memoryUsageBytes"], 67108864)
            self.assertNotIn("PRIVATE_FIXTURE", json.dumps(result))
            self.assertEqual(state.stat().st_mode & 0o777, 0o755)
            self.assertEqual(set(path.name for path in state.iterdir()), {record.name})
            self.assertTrue(all(args[0] in ("list", "stats", "system") for args in calls))
            self.assertTrue(all(args[1] == "df" for args in calls if args[0] == "system"))

    def test_status_reports_unavailable_data_without_starting_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "absent"
            runner = module.Runner({"stateDir": str(state), "container": "container", "networks": {}}, initialize_state=False)
            with patch.object(runner, "container", side_effect=subprocess.TimeoutExpired("fixture", 10)) as calls, patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=1, stdout="")):
                result = runner.status()
            self.assertFalse(state.exists())
            self.assertFalse(result["runtimeAvailable"])
            self.assertIsNone(result["disk"]["images"]["sizeInBytes"])
            calls.assert_called_once()

    def test_commands_and_guard_do_not_wait_for_lifecycle_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "c" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            done, errors = threading.Event(), []
            def work():
                try:
                    with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                        runner.execute(SimpleNamespace(session=session, command=["--", "printf", "fixture"]))
                    with patch.object(runner, "protection_ready", return_value=False):
                        with self.assertRaises(module.SandboxError):
                            runner.guard()
                except Exception as error:
                    errors.append(error)
                finally:
                    done.set()
            worker = threading.Thread(target=work)
            try:
                with runner.lifecycle_lock():
                    worker.start()
                    self.assertTrue(done.wait(2), "agent commands or protection watcher waited on metadata locking")
            finally:
                worker.join(timeout=5)
            self.assertFalse(errors, errors)

    def test_guard_stops_sessions_and_keeps_data_for_guarded_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            args = SimpleNamespace(project=None, image="fixture", network="offline", env=[], cpus=1, memory="512M")
            with patch.object(runner, "protection_ready", return_value=True):
                first, second = runner.create(args), runner.create(args)
            runner.calls.clear()
            with patch.object(runner, "protection_ready", return_value=False):
                with self.assertRaises(module.SandboxError):
                    runner.guard()
                with self.assertRaises(module.SandboxError):
                    runner.start(first)
            self.assertEqual({call[1] for call in runner.calls if call[0] == "stop"}, {first, second})
            self.assertFalse(any(call[0] in ("start", "delete") for call in runner.calls))
            self.assertTrue(runner.record_path(first).exists())
            self.assertTrue(runner.record_path(second).exists())
            with patch.object(runner, "protection_ready", return_value=True):
                runner.start(first)
            self.assertIn(("start", first), runner.calls)
            attempted = []
            def stop(session):
                attempted.append(session)
                if session == first:
                    raise module.SandboxError("fixture stop failure")
            with patch.object(runner, "protection_ready", return_value=False), patch.object(runner, "stop_session", side_effect=stop):
                with self.assertRaisesRegex(module.SandboxError, "could not stop"):
                    runner.guard()
            self.assertEqual(set(attempted), {first, second})

    def test_guard_checks_time_out_and_export_refuses_unprotected_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "e" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            with patch.object(module.subprocess, "run", side_effect=subprocess.TimeoutExpired("fixture check", 5)):
                self.assertFalse(runner.protection_ready())
            with patch.object(runner, "protection_ready", return_value=False), patch.object(module.subprocess, "Popen") as popen:
                with self.assertRaises(module.SandboxError):
                    runner.export(SimpleNamespace(session=session, path=".", timeout=1))
                popen.assert_not_called()

    def test_exports_have_deadlines_and_kill_only_their_fixture_process(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "f" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            for code in (
                "import time; time.sleep(10)",
                "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); print('fixture', flush=True); time.sleep(10)",
                "import os,time; os.close(1); time.sleep(10)",
            ):
                process = fixture_process(code)
                started = time.monotonic()
                try:
                    with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "Popen", return_value=process), patch.object(module, "PROCESS_EXIT_TIMEOUT", 0.05):
                        with self.assertRaises((module.SandboxError, subprocess.TimeoutExpired)):
                            runner.export(SimpleNamespace(session=session, path=".", timeout=0.15))
                    self.assertIsNotNone(process.poll())
                    self.assertLess(time.monotonic() - started, 2)
                    self.assertFalse(list((runner.state / "exports").iterdir()))
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait(timeout=2)

    def test_partial_export_is_removed_even_if_process_cleanup_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "a" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            process = fixture_process("import time; print('fixture', flush=True); time.sleep(10)")
            try:
                with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "Popen", return_value=process), patch.object(module, "stop_export_process", side_effect=subprocess.TimeoutExpired("fixture process", 2)):
                    with self.assertRaises(subprocess.TimeoutExpired):
                        runner.export(SimpleNamespace(session=session, path=".", timeout=0.15))
                self.assertFalse(list((runner.state / "exports").iterdir()))
            finally:
                process.kill()
                process.wait(timeout=2)

    def test_failed_export_spawn_leaves_no_file(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "b" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "Popen", side_effect=OSError("fixture spawn failure")):
                with self.assertRaises(OSError):
                    runner.export(SimpleNamespace(session=session, path=".", timeout=1))
            self.assertFalse(list((runner.state / "exports").iterdir()))

    def test_export_byte_limit_still_removes_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            runner.config["transferLimit"] = 1
            session = "asb-" + "a" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            process = fixture_process("import sys; sys.stdout.buffer.write(b'xy')")
            with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "Popen", return_value=process):
                with self.assertRaisesRegex(module.SandboxError, "transfer limit"):
                    runner.export(SimpleNamespace(session=session, path=".", timeout=2))
            self.assertIsNotNone(process.poll())
            self.assertFalse(list((runner.state / "exports").iterdir()))

    def test_exec_refuses_a_failed_firewall_check(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = FakeRunner(directory)
            session = "asb-" + "d" * 32
            runner.record_path(session).write_text(json.dumps({"network": "offline-0"}))
            calls = []
            def run(args, **kwargs):
                calls.append(args)
                return SimpleNamespace(returncode=1 if args[0] == "/usr/bin/sudo" else 0)
            with patch.object(module.subprocess, "run", side_effect=run):
                with self.assertRaises(module.SandboxError):
                    runner.execute(SimpleNamespace(session=session, command=["--", "printf", "fixture"]))
            self.assertFalse(any(call[:2] == ["container", "exec"] for call in calls))

    def test_overlapping_destroy_cannot_read_a_stale_record(self):
        with tempfile.TemporaryDirectory() as directory:
            first = FakeRunner(directory)
            second = FakeRunner(directory)
            second.resources = first.resources
            args = SimpleNamespace(project=None, image="fixture", network="offline", env=[], cpus=1, memory="512M")
            with patch.object(module.subprocess, "run", return_value=SimpleNamespace(returncode=0)):
                session = first.create(args)
            loaded, release, second_read = threading.Event(), threading.Event(), threading.Event()
            original_first, original_second = first.record, second.record
            errors = []
            def hold_record(session):
                record = original_first(session)
                loaded.set()
                if not release.wait(5):
                    raise RuntimeError("fixture was not released")
                return record
            def observe_record(session):
                second_read.set()
                return original_second(session)
            first.record, second.record = hold_record, observe_record
            def destroy(runner):
                try:
                    runner.destroy(session)
                except Exception as error:
                    errors.append(error)
            workers = [threading.Thread(target=destroy, args=(runner,)) for runner in (first, second)]
            try:
                workers[0].start()
                self.assertTrue(loaded.wait(2))
                workers[1].start()
                self.assertFalse(second_read.wait(0.15), "overlapping cleanup read the same stale record")
            finally:
                release.set()
                for worker in workers:
                    if worker.ident is not None:
                        worker.join(timeout=5)
            self.assertFalse(errors, errors)
            self.assertFalse(any(first.resources.values()))

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
            process = fixture_process(f"import sys; sys.stdout.buffer.write({payload.getvalue()!r})")
            with patch.object(runner, "protection_ready", return_value=True), patch.object(module.subprocess, "Popen", return_value=process):
                exported = runner.export(SimpleNamespace(session=session, path=".", timeout=2))
            self.assertEqual(exported.read_bytes(), payload.getvalue())
            self.assertEqual(outside.read_text(), "unchanged")
            with self.assertRaises(module.SandboxError):
                runner.export(SimpleNamespace(session=session, path="../outside.txt", timeout=2))
            with self.assertRaises(module.SandboxError):
                runner.record_path("../../outside.txt")


if __name__ == "__main__":
    unittest.main()
