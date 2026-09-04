# pi-sandbox: Pi coding agent with a host-only network reserved for this run. Only $PWD (as
# /workspace) and this project's Pi state are visible inside; the network reaches
# this host and nothing else (pf narrows that to Ollama's port), the resolver is loopback so any
# lookup fails in milliseconds, and Pi runs offline. The image builds on the default network.
# Arguments go to Pi; to pass `container run` flags put them first and separate with `--`:
#   pi-sandbox -p "explain this repo"
#   pi-sandbox --mount type=bind,source=$HOME/data,target=/data,readonly -- -p "summarize /data"
# LLM_MODEL=<tag> picks another model for this run only.
# Wrapped by home-manager/llm.nix, which sets LLM_PORT, LLM_MODEL_DEFAULT, LLM_CONTEXT,
# SANDBOX_NETWORKS_FILE and PI_SANDBOX_CONTEXT. The reserved network supplies LLM_SERVER.
run_args=()
pi_args=("$@")
for ((i = 1; i <= $#; i++)); do
  if [ "${!i}" = "--" ]; then
    run_args=("${@:1:i-1}")
    pi_args=("${@:i+1}")
    break
  fi
done
# The launcher owns network selection and waits for the guest before releasing its network.
for arg in "${run_args[@]}"; do
  case $arg in
    --network | --network=* | --detach | --detach=* | -d | --rm | --rm=*)
      echo "pi-sandbox: network and lifecycle flags are managed by the launcher; use shell backgrounding for parallel jobs" >&2
      exit 1 ;;
  esac
done

project=$(pwd -P)
case $project in
  *,* | *=*) echo "pi-sandbox: the working directory path contains ',' or '=', which the container mount syntax cannot carry" >&2; exit 1 ;;
esac
# Canonical paths keep symlink aliases together without sharing trust, sessions or extensions
# between projects. Do not migrate the old shared volume: it may contain executable extensions.
project_id=$(printf '%s' "$project" | /usr/bin/shasum -a 256 | cut -c1-32)

container system start --enable-kernel-install >/dev/null 2>&1 \
  || { echo "pi-sandbox: 'container system start' failed; run it by hand to see why" >&2; exit 1; }

# Tag by the build context's store hash so a changed Dockerfile or entrypoint rebuilds.
image="pi-sandbox:$(basename "$PI_SANDBOX_CONTEXT" | cut -c1-32)"
if ! container image inspect "$image" >/dev/null 2>&1; then
  echo "pi-sandbox: building $image" >&2
  # The vmnet gateway resolver does not answer; the builder gets the host's resolver instead.
  dns=$(/usr/sbin/scutil --dns | awk '/nameserver\[0\]/ { print $3; exit }')
  container builder start ${dns:+--dns "$dns"} >/dev/null 2>&1 || true
  container build -t "$image" "$PI_SANDBOX_CONTEXT"
  # Superseded tags would otherwise pile up (each one carries its own npm layer).
  for old in $(container image list -q 2>/dev/null | grep '^pi-sandbox:' | grep -vx "$image"); do
    container image delete "$old" >/dev/null 2>&1 || true
  done
fi

# Network creation atomically claims a slot, including against concurrent launchers. Never
# attach to an existing network: it may still have a guest after its launcher was interrupted.
network=""
create_error="no network slots configured"
while IFS=$'\t' read -r candidate subnet gateway; do
  if create_error=$(container network create --internal --subnet "$subnet" "$candidate" 2>&1); then
    network=$candidate
    LLM_SERVER=$gateway
    break
  fi
done < <(jq -r '.[] | [.name, .subnet, .gateway] | @tsv' "$SANDBOX_NETWORKS_FILE")
[ -n "$network" ] || { echo "pi-sandbox: no isolated network available: $create_error" >&2; exit 1; }
cleanup_network() {
  # The runtime refuses deletion while a guest is attached. Retain that reservation on an
  # interrupted run rather than let another sandbox join it.
  container network delete "$network" >/dev/null 2>&1 \
    || echo "pi-sandbox: retained network $network; delete it after its container exits" >&2
}
trap cleanup_network EXIT

# -t only with a terminal on stdin: `container run -t` fails with ENOTTY otherwise, and Pi's
# print mode (-p) works fine on a pipe.
tty=(); [ -t 0 ] && tty=(-t)
# Check live rules after network/image preparation, immediately before starting guest code.
/usr/bin/sudo -n /run/current-system/sw/bin/llm-sandbox-check \
  || { echo "pi-sandbox: firewall protection is not ready; refusing to start" >&2; exit 1; }
container run -i "${tty[@]}" --rm --network "$network" --dns 127.0.0.1 \
  --kernel-arg ipv6.disable=1 --cap-drop CAP_NET_RAW --cap-drop CAP_NET_ADMIN \
  --mount "type=bind,source=$project,target=/workspace" --volume "pi-sandbox-home-$project_id:/root/.pi" \
  -e LLM_SERVER="$LLM_SERVER" -e LLM_PORT="$LLM_PORT" -e LLM_CONTEXT="$LLM_CONTEXT" \
  -e LLM_MODEL_DEFAULT="$LLM_MODEL_DEFAULT" ${LLM_MODEL:+-e LLM_MODEL="$LLM_MODEL"} -e PI_OFFLINE=1 \
  "${run_args[@]}" "$image" "${pi_args[@]}"
