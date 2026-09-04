#!/usr/bin/env python3
"""Exercise the built proxy config with real HTTP, without changing system services.

Run with `mise run check-llm-proxy`, or pass a Caddy binary and built Caddyfile.
Only listener addresses and peer ranges are remapped for loopback tests.
"""

import copy
import http.client
import http.server
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time


def objects(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from objects(child)
    elif isinstance(value, list):
        for child in value:
            yield from objects(child)


received = []
finish_stream = threading.Event()


class Upstream(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        received.append((self.command, self.path, body, self.headers["Host"]))
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        self.wfile.write(b'data: {"content":"OK"}\n\n')
        self.wfile.flush()
        finish_stream.wait(5)
        self.wfile.write(b"data: [DONE]\n\n")

    do_GET = do_DELETE = do_POST

    def log_message(self, *args):
        pass


def request(port, method, path, expected, headers=None):
    before = len(received)
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
    try:
        connection.request(method, path, body=b"{}", headers=headers or {})
        response = connection.getresponse()
        assert response.status == expected, (method, path, response.status)
        if expected == 200:
            # The first event must arrive before the upstream finishes its response.
            assert response.readline() == b'data: {"content":"OK"}\n'
            finish_stream.set()
            assert b"[DONE]" in response.read()
            assert received[-1] == (method, path, b"{}", upstream_address)
        else:
            response.read()
            assert len(received) == before, ("blocked request reached upstream", path)
    finally:
        finish_stream.set()
        connection.close()


if len(sys.argv) == 1:
    arguments = json.loads(subprocess.check_output([
        "nix", "eval", "--json", "--option", "eval-cache", "false",
        ".#darwinConfigurations.personal-llm-server.config.home-manager.users",
        "--apply", "users: (builtins.head (builtins.attrValues users)).launchd.agents.llm-proxy.config.ProgramArguments",
    ], text=True))
    caddy, caddyfile = arguments[0], arguments[3]
else:
    caddy, caddyfile = sys.argv[1:]
adapted = subprocess.run(
    [caddy, "adapt", "--adapter", "caddyfile", "--config", caddyfile],
    check=True, capture_output=True, text=True,
)
base_config = json.loads(adapted.stdout)
assert base_config["admin"]["disabled"] is True
upstream = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Upstream)
upstream_address = f"127.0.0.1:{upstream.server_port}"
threading.Thread(target=upstream.serve_forever, daemon=True).start()

try:
    for peer in ("sandbox", "trusted", "unknown"):
        config = copy.deepcopy(base_config)
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        matchers = [o["remote_ip"] for o in objects(config) if "remote_ip" in o]
        assert len(matchers) == 2
        # Sandbox also matches the trusted loopback range: the restricted route must win.
        matchers[0]["ranges"] = ["127.0.0.1" if peer == "sandbox" else "192.0.2.1"]
        matchers[1]["ranges"] = ["192.0.2.2" if peer == "unknown" else "127.0.0.1"]
        for obj in objects(config):
            if "listen" in obj:
                obj["listen"] = [f"127.0.0.1:{port}"]
            if "dial" in obj:
                obj["dial"] = upstream_address
        with tempfile.TemporaryDirectory(prefix="llm-proxy-check-") as directory:
            config_path = Path(directory) / "caddy.json"
            config_path.write_text(json.dumps(config))
            with (Path(directory) / "caddy.log").open("w+") as log:
                process = subprocess.Popen(
                    [caddy, "run", "--config", str(config_path)], stdout=log, stderr=log,
                )
                try:
                    for attempt in range(100):
                        if process.poll() is not None:
                            log.seek(0)
                            raise AssertionError(log.read())
                        try:
                            with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                                break
                        except OSError:
                            time.sleep(0.05)
                    else:
                        raise AssertionError("proxy did not start")
                    finish_stream.clear()
                    request(port, "POST", "/v1/chat/completions", 403 if peer == "unknown" else 200)
                    for method, path in (
                        ("POST", "/api/pull"), ("POST", "/api/push"),
                        ("POST", "/api/create"), ("DELETE", "/api/delete"),
                        ("GET", "/api/tags"), ("GET", "/v1/chat/completions"),
                        ("POST", "/v1/responses"), ("POST", "/v1/messages"),
                        ("POST", "/v1/chat/completions/../../api/pull"),
                        ("POST", "/api/%70ull"),
                    ):
                        request(port, method, path, 200 if peer == "trusted" else 403,
                                {"X-Forwarded-For": "127.0.0.1", "X-Real-IP": "127.0.0.1"})
                    print(f"{peer}: passed")
                finally:
                    process.terminate()
                    process.wait(timeout=5)
finally:
    upstream.shutdown()
    upstream.server_close()
