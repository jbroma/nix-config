#!/usr/bin/env python3
"""Disposable Apple containers. No host directories or control sockets enter the guest."""

import argparse
import contextlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import uuid


class SandboxError(Exception):
    pass


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
    def __init__(self, config):
        self.config = config
        self.state = Path(config["stateDir"])
        self.state.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.state.chmod(0o700)

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
        result = self.container(*arguments, capture=True, check=False, stderr=subprocess.PIPE)
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
                if subprocess.run(["/usr/bin/sudo", "-n", self.config["firewallCheck"]]).returncode:
                    raise SandboxError("firewall protection is not ready")
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
                if args.project:
                    self.container("exec", "-i", session, "/bin/tar", "-xf", "-", "-C", "/workspace", stdin=archive)
            except BaseException:
                self.destroy(session)
                raise
            return session

    def execute(self, args):
        self.record(args.session)
        command = args.command
        if command[:1] == ["--"]:
            command = command[1:]
        if not command:
            raise SandboxError("exec needs a command after --")
        tty = ["-t"] if sys.stdin.isatty() else []
        return subprocess.run([
            self.config["container"], "exec", "-i", *tty, "--workdir", "/workspace", args.session, *command,
        ]).returncode

    def export(self, args):
        self.record(args.session)
        selected = PurePosixPath(args.path)
        if selected.is_absolute() or ".." in selected.parts:
            raise SandboxError("export path must stay inside /workspace")
        directory = self.state / "exports"
        directory.mkdir(mode=0o700, exist_ok=True)
        destination = directory / f"{args.session}-{uuid.uuid4().hex[:8]}.tar"
        # Guest output is untrusted: save bounded bytes, never extract or apply it on the host.
        with destination.open("xb") as output:
            os.chmod(destination, 0o600)
            process = subprocess.Popen([
                self.config["container"], "exec", args.session, "/bin/tar", "-C", "/workspace",
                "-cf", "-", "--", str(selected),
            ], stdout=subprocess.PIPE)
            try:
                total = 0
                while chunk := process.stdout.read(65536):
                    total += len(chunk)
                    if total > self.config["transferLimit"]:
                        raise SandboxError("export exceeds the transfer limit; select a smaller --path")
                    output.write(chunk)
                if process.wait():
                    raise SandboxError("export failed")
            except BaseException:
                process.terminate()
                process.wait(timeout=5)
                destination.unlink(missing_ok=True)
                raise
            finally:
                process.stdout.close()
        return destination

    def destroy(self, session):
        record = self.record(session)
        if self.exists("container", session):
            self.container("stop", session, check=False, stderr=subprocess.DEVNULL)
            self.container("delete", session)
        # Deletion refuses live references. Keep the journal if anything remains for retry.
        remaining = []
        for kind, name in (("volume", session + "-work"), ("volume", session + "-home"), ("network", record["network"])):
            if self.exists(kind, name) and self.container(kind, "delete", name, check=False).returncode:
                remaining.append(name)
        if remaining:
            raise SandboxError("resources still in use; retry destroy: " + ", ".join(remaining))
        self.record_path(session).unlink()


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
    destroy = commands.add_parser("destroy", help="remove this sandbox and its private storage")
    destroy.add_argument("session")
    commands.add_parser("list", help="list retained sandbox IDs")
    commands.add_parser("image", help="build the base image and print its name")
    args = parser.parse_args()
    config_path = os.environ.get("AGENT_SANDBOX_CONFIG", str(Path.home() / ".config/agent-sandbox/config.json"))
    runner = Runner(json.loads(Path(config_path).read_text()))
    if args.action == "create":
        print(runner.create(args))
    elif args.action == "exec":
        return runner.execute(args)
    elif args.action == "export":
        print(runner.export(args))
    elif args.action == "destroy":
        runner.destroy(args.session)
    elif args.action == "list":
        for path in sorted(runner.state.glob("asb-*.json")):
            print(path.stem)
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
