#!/usr/bin/env bash
# Configure Pi in the private home supplied by agent-sandbox, then run it. State in ~/.pi/agent
# stays inside this sandbox across repeated exec calls. The Ollama provider entry is upserted
# by model id and the default model is only seeded when missing.
# LLM_MODEL, when set, is used for this run only via Pi's --provider/--model flags.
set -euo pipefail
LLM_SERVER="${SANDBOX_GATEWAY:?set SANDBOX_GATEWAY to the model gateway}"
: "${LLM_PORT:?set LLM_PORT to the Ollama port}"
: "${LLM_CONTEXT:?set LLM_CONTEXT to the context window}"
: "${LLM_MODEL_DEFAULT:?set LLM_MODEL_DEFAULT to the default model tag}"
agent=~/.pi/agent
mkdir -p "$agent"

# update <file> <jq-filter> [jq args...]: rewrite a JSON object file in place (same directory, so
# the final rename is atomic). Anything that is not a JSON object (Pi killed mid-write, a stray
# `null`) is moved aside, not fatal.
update() {
  local f=$1 filter=$2 tmp
  shift 2
  if [ -s "$f" ] && ! jq -e 'type == "object"' "$f" >/dev/null 2>&1; then
    echo "entrypoint: $f is not a JSON object, moving to $f.corrupt" >&2
    mv "$f" "$f.corrupt"
  fi
  tmp=$(mktemp "$f.XXXXXX")
  if [ -s "$f" ]; then jq "$@" "$filter" "$f" > "$tmp"; else jq -n "$@" "$filter" > "$tmp"; fi \
    || { rm -f "$tmp"; echo "entrypoint: could not update $f" >&2; exit 1; }
  mv "$tmp" "$f"
}

# upsert_model <tag>: make sure the Ollama provider lists this model.
upsert_model() {
  update "$agent/models.json" '
    (.providers.ollama.models | if type == "array" then . else [] end | map(select(.id != $model))) as $others
    | .providers.ollama.baseUrl = "http://\($server):\($port)/v1"
    | .providers.ollama.api = "openai-completions"
    | .providers.ollama.apiKey = "ollama"
    | .providers.ollama.models = $others + [ { id: $model, reasoning: true, contextWindow: $ctx, maxTokens: 32768 } ]
  ' --arg server "$LLM_SERVER" --arg port "$LLM_PORT" --arg model "$1" --argjson ctx "$LLM_CONTEXT"
}

upsert_model "$LLM_MODEL_DEFAULT"
update "$agent/settings.json" '.defaultProvider //= "ollama" | .defaultModel //= $model' --arg model "$LLM_MODEL_DEFAULT"

# A per-run model is not written to models.json: Pi accepts an unlisted model id for a provider
# that has at least one model (with a warning), and nothing persists on the volume.
if [ -n "${LLM_MODEL:-}" ]; then
  exec pi --provider ollama --model "$LLM_MODEL" "$@"
fi
exec pi "$@"
