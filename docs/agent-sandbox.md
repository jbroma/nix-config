# Agent sandboxes

`agent-sandbox` runs Linux tools in disposable Apple containers on Apple Silicon with macOS 26.
It does not mount host
directories or forward host control sockets. Pi uses the same runner.

## Enable

Set `agentSandbox = true;` in the machine's local `user.nix`, then apply the configuration
manually. The LLM server role enables sandboxes automatically. The standalone role works
without Ollama. Internet mode uses Homebrew's Squid package, installed by that configuration.

## Use

```sh
# Snapshot tracked and unignored working files from this Git project.
session=$(agent-sandbox create --project . --network internet)
agent-sandbox exec "$session" -- npm test

# More commands use the same private workspace.
agent-sandbox exec "$session" -- python3 -c 'print("hello from the sandbox")'

# Save results for review. This prints the path to a new archive.
agent-sandbox export "$session" --path src
agent-sandbox destroy "$session"
```

Omit `--project` for an empty workspace. `create` prints only the sandbox ID to stdout;
diagnostics go to stderr. `exec` returns the guest command's exit code. `list` shows retained
sandboxes. `destroy` removes only the resources recorded for that sandbox. If the runtime is
unavailable or a resource is still in use, the record stays available for a retry.
Creation, restart and destruction lock their resource changes. Repeated destruction is harmless;
agent commands and exports remain parallel and do not hold that lock.

The workspace is a snapshot, not a live mount. Host edits after creation do not appear in the
sandbox, and guest edits do not change the source project. Ignored files and `.git` metadata
are excluded; tracked files remain eligible even if they contain credentials. Symlinks are
copied as links without reading their targets. Git worktrees are supported through Git's file
listing rather than copying their external metadata directories.
The snapshot has no Git history. Submodules are not expanded; snapshot a submodule separately.

Exports are bounded, untrusted archive bytes under `~/.local/state/agent-sandbox/exports`.
The runner never extracts an archive, applies a patch, or overwrites a host project. Review
the archive before using its contents. Select a smaller `--path` if the export exceeds 512 MiB.
Destroying a sandbox does not remove previously exported archives.
Exports have a five-minute deadline. `export --timeout SECONDS` can change it up to one hour.
Timeouts, failed starts and interrupted exports remove the partial archive. Export-process
cleanup escalates from termination to killing only that export process, with bounded waits.

## Network profiles

| Profile | Access |
| --- | --- |
| `offline`, the default | No model or internet proxy access. |
| `internet` | Public HTTP/HTTPS on ports 80 and 443 through the configured proxy. Private, loopback, link-local and reserved destinations are denied. |
| `model` | Only the local inference proxy, available on the LLM server. |

Profiles have separate address ranges enforced by pf. Setting `HTTP_PROXY` inside an offline
guest does not change its access. Each run reserves its own host-only network, preventing
direct access to other sandboxes. IPv6 and raw-packet privileges are disabled in guests.
There are 32 network reservations per profile.

Protection is checked during creation, before every command/export, and before and after a
restart. A user launchd job also polls every five seconds and attempts to stop all managed
sandboxes when the check fails or times out, preserving their files. It does not delete data
or wait for resource-management locking. Polling is not instantaneous; an unavailable runtime
can prevent a stop. Failures are logged to `~/.local/state/agent-sandbox/guard.log` and retried.
After restoring protection, use `agent-sandbox start ID` to restart a retained sandbox before
continuing work or exporting its files.

Internet mode sets `http_proxy`, `https_proxy`, their uppercase equivalents, and
`NODE_USE_ENV_PROXY=1`. Tools must support an HTTP proxy. Direct TCP, UDP, SSH and DNS are
not provided; CONNECT tunnels on port 443 are allowed without inspecting their application
protocol. API keys, SSH credentials and host environment variables are not inherited.
Public internet access can transmit any data deliberately copied into that sandbox.

## Storage and resources

Inspect usage on the machine running the sandboxes:

```sh
agent-sandbox status
agent-sandbox status --json
```

The report is read-only. It shows retained sandbox IDs and state, CPU usage from two samples,
guest memory usage/limits, all Apple Container disk usage, retained exports, and host load and
memory pressure. CPU 100% means one fully used core. Metrics unavailable from a stopped runtime
are marked unknown. Environment variables and mount paths are excluded from JSON output.
For a continuous native CPU/memory display, use `container stats`.

Cleanup remains explicit: export any results you want to keep, then run
`agent-sandbox destroy ID`. Export archives and cached images remain. The runtime's reported
reclaimable storage can include retained work; the status command never prunes it.

The image filesystem is read-only. Each session has a private 4 GiB workspace volume,
512 MiB home volume and 256 MiB temporary filesystem. Default CPU and memory limits are
2 CPUs and 2 GiB; `create --cpus` and `--memory` choose other bounded values. Use a prepared
`--image` when additional system packages are needed; package installation into the image
filesystem is not available during a session.

These controls reduce accidental host damage. They are not a guarantee against runtime
vulnerabilities or aggregate disk and memory exhaustion from many sessions and cached images.
Keep session creation under a trusted controller and give agents only sandbox execution tools,
not an unrestricted host shell. Host-side agent integrations are not installed automatically.

## Pi

`pi-sandbox -p "inspect this project"` builds Pi on the shared development image, creates a
model-only sandbox, and invokes Pi there. It prints the sandbox ID and retains results for
explicit export and destruction. Each session starts with fresh Pi state; the old shared and
per-project Pi volumes are not imported or removed. Extra host mount flags are no longer
accepted. `LLM_MODEL` still selects a model for a run.

## Verification

`mise run check-agent-sandbox` builds the standalone role and tests snapshots, archive export,
parallel resource reservations and cleanup with harmless temporary fixtures.
`mise run check-agent-sandbox-firewall`, `check-llm-proxy` and `check-pi-sandbox` verify the
policy and Pi integration. The personal, work and forced LLM-server builds remain required.
System activation and a final smoke test of the deployed policy are manual steps.
After activation, `mise run check-agent-sandbox-live` exercises two 512 MiB sandboxes with
temporary text fixtures and retains the exported fixture archive for inspection. It does not
run deletion probes, host-write attempts or resource-exhaustion tests.
