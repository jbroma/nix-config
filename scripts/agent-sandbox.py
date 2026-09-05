#!/usr/bin/env python3
"""Disposable Apple containers. No host directories or control sockets enter the guest."""

import argparse
import contextlib
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid


class SandboxError(Exception):
    pass


PROCESS_EXIT_TIMEOUT = 2


def stop_export_process(process):
    """Bound cleanup of the host-side export process, including a terminate-resistant child."""
    if process.poll() is not None:
        return
    for action in (process.terminate, process.kill):
        try:
            action()
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=PROCESS_EXIT_TIMEOUT)
            return
        except subprocess.TimeoutExpired:
            continue
    raise SandboxError("export process did not exit after termination")


def snapshot(project, output, limit):
    """Copy Git working files, excluding ignored files and Git metadata, without following links."""
    project = Path(project).resolve(strict=True)
    names = subprocess.check_output([
        "git", "-c", "core.fsmonitor=false", "-C", str(project),
        "ls-files", "-z", "--cached", "--others", "--exclude-standard",
    ]).split(b"\0")
    total = 0
    with tarfile.open(fileobj=output, mode="w") as archive:
        for raw in sorted(set(names) - {b""}):
            name = os.fsdecode(raw)
            parts = PurePosixPath(name).parts
            if not parts or any(part == ".." or part.casefold() == ".git" for part in parts) or name.startswith("/"):
                raise SandboxError("unsafe path in project snapshot")
            with contextlib.ExitStack() as stack:
                parent = os.open(project, os.O_RDONLY | os.O_DIRECTORY)
                stack.callback(os.close, parent)
                try:
                    for part in parts[:-1]:
                        parent = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
                        stack.callback(os.close, parent)
                    info = os.stat(parts[-1], dir_fd=parent, follow_symlinks=False)
                except FileNotFoundError:
                    continue  # A tracked working file may have been deleted.
                member = tarfile.TarInfo(name)
                member.mode = stat.S_IMODE(info.st_mode) & 0o777
                if stat.S_ISLNK(info.st_mode):
                    member.type = tarfile.SYMTYPE
                    member.linkname = os.readlink(parts[-1], dir_fd=parent)
                    archive.addfile(member)
                elif stat.S_ISREG(info.st_mode):
                    fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
                    with os.fdopen(fd, "rb") as source:
                        opened = os.fstat(source.fileno())
                        if not stat.S_ISREG(opened.st_mode):
                            raise SandboxError("snapshot file changed type while opening it")
                        member.size = opened.st_size
                        total += member.size
                        if total > limit:
                            raise SandboxError("project snapshot exceeds the transfer limit")
                        archive.addfile(member, source)
                else:
                    raise SandboxError(f"snapshot only accepts regular files and symlinks: {name}")
                if output.tell() > limit:
                    raise SandboxError("project snapshot exceeds the transfer limit")
    if output.tell() > limit:
        raise SandboxError("project snapshot exceeds the transfer limit")
    output.seek(0)


class Runner:
    def __init__(self, config, initialize_state=True):
        self.config = config
        self.state = Path(config["stateDir"])
        if initialize_state:
            self.state.mkdir(mode=0o700, parents=True, exist_ok=True)
            self.state.chmod(0o700)

    def status(self):
        """Read runtime metrics without starting services, changing permissions, or cleaning up."""
        issues = []
        def read_json(*args):
            try:
                result = self.container(*args, capture=True, check=False, stderr=subprocess.PIPE, timeout=10)
                if result.returncode == 0:
                    return json.loads(result.stdout)
            except (OSError, ValueError, subprocess.SubprocessError):
                pass
            issues.append(f"{' '.join(args[:2])} unavailable")
            return None

        def number(value):
            return value if type(value) is int and 0 <= value < 2**64 else None

        def by_id(value):
            return {item["id"]: item for item in value
                    if isinstance(item, dict) and isinstance(item.get("id"), str)} if isinstance(value, list) else {}

        def sysctl(key):
            try:
                result = subprocess.run(["/usr/sbin/sysctl", "-n", key], capture_output=True, timeout=2, text=True)
                return int(result.stdout) if result.returncode == 0 else None
            except (OSError, ValueError, subprocess.SubprocessError):
                return None

        inventory = read_json("list", "--all", "--format", "json")
        available = isinstance(inventory, list)
        containers = by_id(inventory)
        sessions = []
        for path in sorted(self.state.glob("asb-*.json")):
            try:
                record = self.record(path.stem)
            except FileNotFoundError:
                continue  # Cleanup may have just finished.
            except (SandboxError, OSError, ValueError, TypeError):
                issues.append("invalid sandbox record")
                continue
            entry = containers.get(path.stem, {})
            native_state = entry.get("status")
            state = native_state.get("state") if isinstance(native_state, dict) else ("missing" if available and not entry else "unknown")
            if state not in ("running", "stopped", "starting", "stopping", "created", "missing"):
                state = "unknown"
            mode = record.get("mode")
            sessions.append({
                "id": path.stem, "mode": mode if isinstance(mode, str) and mode in self.config["networks"] else "unknown",
                "state": state, "cpuPercent": None, "memoryUsageBytes": None, "memoryLimitBytes": None,
            })
        running = [session["id"] for session in sessions if session["state"] == "running"]
        if running:
            first = read_json("stats", *running, "--no-stream", "--format", "json")
            started = time.monotonic()
            time.sleep(1)
            last = read_json("stats", *running, "--no-stream", "--format", "json")
            elapsed = time.monotonic() - started
            first, last = by_id(first), by_id(last)
            for session in sessions:
                before, current = first.get(session["id"], {}), last.get(session["id"], {})
                old_cpu, new_cpu = number(before.get("cpuUsageUsec")), number(current.get("cpuUsageUsec"))
                if old_cpu is not None and new_cpu is not None and new_cpu >= old_cpu and elapsed > 0:
                    session["cpuPercent"] = round((new_cpu - old_cpu) / (elapsed * 10000), 1)
                for key in ("memoryUsageBytes", "memoryLimitBytes"):
                    session[key] = number(current.get(key))
        raw_disk = read_json("system", "df", "--format", "json") if available else None
        disk = {}
        for kind in ("containers", "images", "volumes"):
            entry = raw_disk.get(kind, {}) if isinstance(raw_disk, dict) else {}
            if not isinstance(entry, dict):
                entry = {}
            disk[kind] = {key: number(entry.get(key)) for key in ("total", "active", "sizeInBytes", "reclaimable")}
        exports = {"count": 0, "sizeInBytes": 0}
        for path in (self.state / "exports").glob("*.tar"):
            try:
                info = path.lstat()
                if stat.S_ISREG(info.st_mode):
                    exports["count"] += 1
                    exports["sizeInBytes"] += info.st_size
            except FileNotFoundError:
                continue
        return {
            "runtimeAvailable": available, "sessions": sessions, "disk": disk, "exports": exports,
            "host": {"load1m": round(os.getloadavg()[0], 2), "logicalCpus": os.cpu_count(),
                     "memoryTotalBytes": sysctl("hw.memsize"),
                     "memoryPressure": {1: "normal", 2: "warning", 4: "critical"}.get(sysctl("kern.memorystatus_vm_pressure_level"), "unknown")},
            "issues": issues,
        }

    @contextlib.contextmanager
    def lifecycle_lock(self):
        # This file is never unlinked: all processes must lock the same inode. Commands and
        # exports do not hold this lock, so running sandboxes remain independent.
        fd = os.open(self.state / ".lifecycle.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "r+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)

    def protection_ready(self):
        try:
            return subprocess.run(
                ["/usr/bin/sudo", "-n", self.config["firewallCheck"]],
                capture_output=True, timeout=5,
            ).returncode == 0
        except (OSError, subprocess.SubprocessError):
            return False

    def stop_session(self, session):
        result = self.container("stop", session, capture=True, check=False, stderr=subprocess.PIPE, timeout=10)
        if result.returncode and self.exists("container", session):
            raise SandboxError(f"could not stop {session}; its files and record are retained")

    def require_protection(self, session=None):
        if self.protection_ready():
            return
        if session is not None:
            self.stop_session(session)
        raise SandboxError("firewall protection is unavailable; guest execution refused")

    def guard(self):
        sessions = [path.stem for path in self.state.glob("asb-*.json")
                    if re.fullmatch(r"asb-[0-9a-f]{32}", path.stem)]
        if not sessions or self.protection_ready():
            return
        # Stopping immutable session IDs never deletes or reuses a network reservation and
        # must not wait behind a create/destroy lock when protection has failed.
        failed = []
        with ThreadPoolExecutor(max_workers=min(8, len(sessions))) as workers:
            pending = {workers.submit(self.stop_session, session): session for session in sessions}
            for future in as_completed(pending):
                try:
                    future.result()
                except (SandboxError, OSError, subprocess.SubprocessError):
                    failed.append(pending[future])
        if failed:
            raise SandboxError("firewall unavailable; could not stop: " + ", ".join(failed))
        raise SandboxError("firewall unavailable; managed sandboxes stopped, files retained")

    def container(self, *args, capture=False, check=True, **kwargs):
        result = subprocess.run(
            [self.config["container"], *map(str, args)],
            stdout=subprocess.PIPE if capture else sys.stderr, **kwargs,
        )
        if check and result.returncode:
            raise SandboxError(f"container {args[0]} failed")
        return result

    def exists(self, kind, name):
        arguments = ("inspect", name) if kind == "container" else (kind, "inspect", name)
        result = self.container(*arguments, capture=True, check=False, stderr=subprocess.PIPE, timeout=10)
        if result.returncode == 0:
            return True
        if name.encode() in result.stderr and re.search(rb"notFound|not found|does not exist", result.stderr, re.IGNORECASE):
            return False
        raise SandboxError(f"could not inspect {kind}; keeping the sandbox record for retry")

    def record_path(self, session):
        if not re.fullmatch(r"asb-[0-9a-f]{32}", session):
            raise SandboxError("invalid sandbox ID")
        return self.state / f"{session}.json"

    def record(self, session):
        record = json.loads(self.record_path(session).read_text())
        if not isinstance(record, dict) or record.get("network") not in {
            item["name"] for pool in self.config["networks"].values() for item in pool
        }:
            raise SandboxError("sandbox record has an unknown network")
        return record

    def image(self):
        context = self.config["context"]
        image = "agent-sandbox:" + Path(context).name.split("-", 1)[0]
        if self.container("image", "inspect", image, capture=True, check=False, stderr=subprocess.DEVNULL).returncode:
            dns = subprocess.check_output(["/usr/sbin/scutil", "--dns"], text=True)
            match = re.search(r"nameserver\[0\]\s*:\s*(\S+)", dns)
            options = ["--dns", match[1]] if match else []
            self.container("builder", "start", *options)
            self.container("build", "-t", image, context)
        return image

    def create(self, args):
        if args.image and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:/@-]*", args.image):
            raise SandboxError("invalid image reference")
        if args.network == "model" and self.config["modelPort"] is None:
            raise SandboxError("model access is not configured on this machine")
        with tempfile.TemporaryFile() as archive:
            if args.project:
                snapshot(args.project, archive, self.config["transferLimit"])
            self.container("system", "start", "--enable-kernel-install")
            image = args.image or self.image()
            with self.lifecycle_lock():
                network = None
                for candidate in self.config["networks"][args.network]:
                    result = self.container(
                        "network", "create", "--internal", "--subnet", candidate["subnet"], candidate["name"],
                        capture=True, check=False, stderr=subprocess.DEVNULL,
                    )
                    if result.returncode == 0:
                        network = candidate
                        break
                if network is None:
                    raise SandboxError("no isolated network available; inspect existing sandbox reservations")
                session = "asb-" + uuid.uuid4().hex
                record = {"network": network["name"], "mode": args.network}
                journal_created = False
                try:
                    with self.record_path(session).open("x") as journal:
                        journal_created = True
                        journal.write(json.dumps(record))
                except BaseException:
                    self.container("network", "delete", network["name"], check=False)
                    if journal_created:
                        self.record_path(session).unlink(missing_ok=True)
                    raise
                try:
                    self.require_protection()
                    self.container("volume", "create", "-s", "4G", session + "-work")
                    self.container("volume", "create", "-s", "512M", session + "-home")
                    environment = ["SANDBOX_GATEWAY=" + network["gateway"]]
                    if args.network == "internet":
                        proxy = f"http://{network['gateway']}:{self.config['proxyPort']}"
                        environment += [f"{key}={proxy}" for key in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY")]
                        environment.append("NODE_USE_ENV_PROXY=1")
                    for value in args.env:
                        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", value, re.DOTALL):
                            raise SandboxError("--env requires KEY=value")
                        environment.append(value)
                    env_flags = [part for value in environment for part in ("--env", value)]
                    self.container(
                        "run", "-d", "--name", session, "--label", "agent-sandbox.managed=true",
                        "--network", network["name"], "--dns", "127.0.0.1", "--read-only",
                        "--cpus", str(args.cpus), "--memory", args.memory,
                        "--kernel-arg", "ipv6.disable=1", "--cap-drop", "CAP_NET_RAW", "--cap-drop", "CAP_NET_ADMIN", "--cap-drop", "CAP_MKNOD",
                        "--mount", "type=tmpfs,target=/tmp,size=256M",
                        "--volume", session + "-work:/workspace", "--volume", session + "-home:/root",
                        *env_flags, "--entrypoint", "/bin/sleep", image, "infinity",
                    )
                    self.require_protection(session)
                    if args.project:
                        self.container("exec", "-i", session, "/bin/tar", "-xf", "-", "-C", "/workspace", stdin=archive)
                    self.require_protection(session)
                except BaseException:
                    self._destroy_locked(session)
                    raise
                return session

    def execute(self, args):
        self.record(args.session)
        command = args.command
        if command[:1] == ["--"]:
            command = command[1:]
        if not command:
            raise SandboxError("exec needs a command after --")
        self.require_protection(args.session)
        tty = ["-t"] if sys.stdin.isatty() else []
        return subprocess.run([
            self.config["container"], "exec", "-i", *tty, "--workdir", "/workspace", args.session, *command,
        ]).returncode

    def export(self, args):
        self.record(args.session)
        if not 0 < args.timeout <= 3600:
            raise SandboxError("export timeout must be between 0 and 3600 seconds")
        selected = PurePosixPath(args.path)
        if selected.is_absolute() or ".." in selected.parts:
            raise SandboxError("export path must stay inside /workspace")
        self.require_protection(args.session)
        directory = self.state / "exports"
        directory.mkdir(mode=0o700, exist_ok=True)
        destination = directory / f"{args.session}-{uuid.uuid4().hex[:8]}.tar"
        # Guest output is untrusted: save bounded bytes, never extract or apply it on the host.
        with destination.open("xb") as output:
            process = None
            try:
                os.chmod(destination, 0o600)
                deadline = time.monotonic() + args.timeout
                process = subprocess.Popen([
                    self.config["container"], "exec", args.session, "/bin/tar", "-C", "/workspace",
                    "-cf", "-", "--", str(selected),
                ], stdout=subprocess.PIPE)
                total = 0
                os.set_blocking(process.stdout.fileno(), False)
                with selectors.DefaultSelector() as ready:
                    ready.register(process.stdout, selectors.EVENT_READ)
                    while True:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0 or not ready.select(remaining):
                            raise SandboxError("export timed out")
                        chunk = os.read(process.stdout.fileno(), 65536)
                        if not chunk:
                            break
                        total += len(chunk)
                        if total > self.config["transferLimit"]:
                            raise SandboxError("export exceeds the transfer limit; select a smaller --path")
                        output.write(chunk)
                if process.wait(timeout=max(0, deadline - time.monotonic())):
                    raise SandboxError("export failed")
            except BaseException:
                try:
                    if process is not None:
                        stop_export_process(process)
                finally:
                    destination.unlink(missing_ok=True)
                raise
            finally:
                if process is not None:
                    process.stdout.close()
        return destination

    def destroy(self, session):
        with self.lifecycle_lock():
            if self.record_path(session).exists():
                self._destroy_locked(session)

    def _destroy_locked(self, session):
        record = self.record(session)
        if self.exists("container", session):
            self.stop_session(session)
            self.container("delete", session)
        # Deletion refuses live references. Keep the journal if anything remains for retry.
        remaining = []
        for kind, name in (("volume", session + "-work"), ("volume", session + "-home"), ("network", record["network"])):
            if self.exists(kind, name) and self.container(kind, "delete", name, check=False).returncode:
                remaining.append(name)
        if remaining:
            raise SandboxError("resources still in use; retry destroy: " + ", ".join(remaining))
        self.record_path(session).unlink()

    def start(self, session):
        with self.lifecycle_lock():
            self.record(session)
            self.require_protection(session)
            self.container("start", session)
            self.require_protection(session)


def print_status(report):
    def size(value):
        if value is None:
            return "?"
        for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
            if value < 1024 or unit == "TiB":
                return f"{value:.1f}{unit}"
            value /= 1024
    host = report["host"]
    print(f"Host: 1m load {host['load1m']}; {host['logicalCpus']} logical CPUs; total RAM {size(host['memoryTotalBytes'])}; memory pressure {host['memoryPressure']}")
    print(f"Runtime: {'available' if report['runtimeAvailable'] else 'unavailable'}; retained sandboxes: {len(report['sessions'])}")
    if report["sessions"]:
        print(f"{'ID':36} {'MODE':8} {'STATE':8} {'CPU':>7}  GUEST MEMORY / LIMIT")
        for session in report["sessions"]:
            cpu = f"{session['cpuPercent']:.1f}%" if session["cpuPercent"] is not None else "?"
            print(f"{session['id']:36} {session['mode']:8} {session['state']:8} {cpu:>7}  {size(session['memoryUsageBytes'])} / {size(session['memoryLimitBytes'])}")
        print("CPU: 100% is one core. ? means unavailable, not zero.")
    print("All Apple Container storage:")
    for kind, entry in report["disk"].items():
        print(f"  {kind}: {size(entry['sizeInBytes'])}; reported reclaimable {size(entry['reclaimable'])}")
    print(f"Retained export archives: {report['exports']['count']}, {size(report['exports']['sizeInBytes'])}")
    if report["issues"]:
        print("Incomplete data: " + "; ".join(sorted(set(report["issues"]))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    create = commands.add_parser("create", help="create a private workspace and print its sandbox ID")
    create.add_argument("--project", help="Git working tree to snapshot; omitted for an empty workspace")
    create.add_argument("--image", help="prebuilt image; defaults to the bundled development image")
    create.add_argument("--network", choices=("offline", "internet", "model"), default="offline")
    create.add_argument("--env", action="append", default=[])
    create.add_argument("--cpus", type=int, choices=range(1, 9), default=2)
    create.add_argument("--memory", choices=("512M", "1G", "2G", "4G", "8G"), default="2G")
    execute = commands.add_parser("exec", help="run a command inside an existing sandbox")
    execute.add_argument("session")
    execute.add_argument("command", nargs=argparse.REMAINDER)
    export = commands.add_parser("export", help="write a new archive under the private exports directory")
    export.add_argument("session")
    export.add_argument("--path", default=".")
    export.add_argument("--timeout", type=float, default=300, help="export deadline in seconds, at most 3600")
    destroy = commands.add_parser("destroy", help="remove this sandbox and its private storage")
    destroy.add_argument("session")
    start = commands.add_parser("start", help="restart a retained sandbox after protection is restored")
    start.add_argument("session")
    commands.add_parser("guard", help="stop managed sandboxes when firewall protection is unavailable")
    commands.add_parser("list", help="list retained sandbox IDs")
    status = commands.add_parser("status", help="read sandbox CPU, memory, disk and retained export usage")
    status.add_argument("--json", action="store_true", help="emit a machine-readable snapshot")
    commands.add_parser("image", help="build the base image and print its name")
    args = parser.parse_args()
    config_path = os.environ.get("AGENT_SANDBOX_CONFIG", str(Path.home() / ".config/agent-sandbox/config.json"))
    runner = Runner(json.loads(Path(config_path).read_text()), initialize_state=args.action != "status")
    if args.action == "create":
        print(runner.create(args))
    elif args.action == "exec":
        return runner.execute(args)
    elif args.action == "export":
        print(runner.export(args))
    elif args.action == "destroy":
        runner.destroy(args.session)
    elif args.action == "start":
        runner.start(args.session)
    elif args.action == "guard":
        runner.guard()
    elif args.action == "list":
        for path in sorted(runner.state.glob("asb-*.json")):
            print(path.stem)
    elif args.action == "status":
        report = runner.status()
        if args.json:
            print(json.dumps(report))
        else:
            print_status(report)
    elif args.action == "image":
        runner.container("system", "start", "--enable-kernel-install")
        print(runner.image())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (SandboxError, OSError, ValueError, tarfile.TarError, subprocess.SubprocessError) as error:
        print(f"agent-sandbox: {error}", file=sys.stderr)
        sys.exit(1)
