# Pi is one consumer of agent-sandbox. It gets a disposable project snapshot and fresh state.
base=$(agent-sandbox image)
image="pi-sandbox:$(printf '%s\n' "$base" "$PI_SANDBOX_CONTEXT" | /usr/bin/shasum -a 256 | cut -c1-32)"
if ! container image inspect "$image" >/dev/null 2>&1; then
  container build --build-arg "BASE_IMAGE=$base" -t "$image" "$PI_SANDBOX_CONTEXT"
fi
model=()
if [ -n "${LLM_MODEL:-}" ]; then model=(--env "LLM_MODEL=$LLM_MODEL"); fi
session=$(agent-sandbox create --project "$PWD" --image "$image" --network model \
  --env "LLM_PORT=$LLM_PORT" --env "LLM_CONTEXT=$LLM_CONTEXT" \
  --env "LLM_MODEL_DEFAULT=$LLM_MODEL_DEFAULT" --env PI_OFFLINE=1 "${model[@]}")
echo "Pi sandbox: $session" >&2
trap 'echo "Retained $session. Export with: agent-sandbox export $session; remove with: agent-sandbox destroy $session" >&2' EXIT
agent-sandbox exec "$session" -- /usr/local/bin/entrypoint "$@"
