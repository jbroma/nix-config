# pi-sandbox: Pi coding agent in an Apple container on a host-only network. Only $PWD (as
# /workspace) and Pi's own state (volume pi-sandbox-home) are visible inside; the network reaches
# this host and nothing else (pf narrows that to Ollama's port), the resolver is loopback so any
# lookup fails in milliseconds, and Pi runs offline. The image builds on the default network.
# Arguments go to Pi; to pass `container run` flags put them first and separate with `--`:
#   pi-sandbox -p "explain this repo"
#   pi-sandbox --mount type=bind,source=$HOME/data,target=/data,readonly -- -p "summarize /data"
# LLM_MODEL=<tag> picks another model for this run only.
# Wrapped by home-manager/llm.nix, which sets LLM_SERVER, LLM_PORT, LLM_MODEL_DEFAULT, LLM_CONTEXT,
# SANDBOX_NETWORK, SANDBOX_SUBNET and PI_SANDBOX_CONTEXT.
run_args=()
pi_args=("$@")
for ((i = 1; i <= $#; i++)); do
  if [ "${!i}" = "--" ]; then
    run_args=("${@:1:i-1}")
    pi_args=("${@:i+1}")
    break
  fi
done

case $PWD in
  *,* | *=*) echo "pi-sandbox: the working directory path contains ',' or '=', which the container mount syntax cannot carry" >&2; exit 1 ;;
esac

container system start --enable-kernel-install >/dev/null 2>&1 \
  || { echo "pi-sandbox: 'container system start' failed; run it by hand to see why" >&2; exit 1; }

# Host-only network on the subnet the pf rules are written for; created once, checked every run
# for both properties. (inspect exits non-zero for a missing network; under pipefail that must
# not abort the script.)
net=$(container network inspect "$SANDBOX_NETWORK" 2>/dev/null | jq -r '"\(.[0].configuration.mode) \(.[0].status.ipv4Subnet)"' || true)
if [ -z "$net" ]; then
  container network create --internal --subnet "$SANDBOX_SUBNET" "$SANDBOX_NETWORK" >/dev/null
elif [ "$net" != "hostOnly $SANDBOX_SUBNET" ]; then
  echo "pi-sandbox: network $SANDBOX_NETWORK is '$net', expected 'hostOnly $SANDBOX_SUBNET'; 'container network delete $SANDBOX_NETWORK' and rerun" >&2
  exit 1
fi

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

# -t only with a terminal on stdin: `container run -t` fails with ENOTTY otherwise, and Pi's
# print mode (-p) works fine on a pipe.
tty=(); [ -t 0 ] && tty=(-t)
exec container run -i "${tty[@]}" --rm --network "$SANDBOX_NETWORK" --dns 127.0.0.1 \
  --mount "type=bind,source=$PWD,target=/workspace" --volume pi-sandbox-home:/root/.pi \
  -e LLM_SERVER="$LLM_SERVER" -e LLM_PORT="$LLM_PORT" -e LLM_CONTEXT="$LLM_CONTEXT" \
  -e LLM_MODEL_DEFAULT="$LLM_MODEL_DEFAULT" ${LLM_MODEL:+-e LLM_MODEL="$LLM_MODEL"} -e PI_OFFLINE=1 \
  "${run_args[@]}" "$image" "${pi_args[@]}"
