#!/usr/bin/env bash
set -euo pipefail

# Claude Code statusline script

# ANSI color codes
reset=$'\033[0m'
dim=$'\033[2m'
cyan=$'\033[36m'
green=$'\033[32m'
yellow=$'\033[33m'
red=$'\033[31m'
magenta=$'\033[35m'

# Read JSON input from stdin
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
project_name=$(basename "$project_dir" 2>/dev/null || echo "")

# Token usage from context window
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // null')

# Git information
git_branch=""
git_dirty=false
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    # Check if dirty (has changes)
    if ! git -C "$cwd" diff-index --quiet HEAD -- 2>/dev/null; then
        git_dirty=true
    fi
fi

# Format token count with k/M suffix
format_tokens() {
    local count=$1
    if [[ $count -ge 1000000 ]]; then
        awk "BEGIN {printf \"%.1fM\", $count/1000000}"
    elif [[ $count -ge 1000 ]]; then
        awk "BEGIN {printf \"%.1fk\", $count/1000}"
    else
        echo "$count"
    fi
}

# Build status line
parts=()
blue=$'\033[34m'
bold=$'\033[1m'
white=$'\033[97m'

# Project directory
if [[ -n "$project_name" ]]; then
    parts+=("${white}${project_name}${reset}")
fi

# Git branch (green if clean, yellow if dirty)
if [[ -n "$git_branch" ]]; then
    if [[ "$git_dirty" == true ]]; then
        parts+=("${yellow}${git_branch}*${reset}")
    else
        parts+=("${green}${git_branch}${reset}")
    fi
fi

# Model name (colored by tier)
if [[ "$model" == *"Opus"* ]]; then
    parts+=("${bold}${magenta}opus-4.5${reset}")
elif [[ "$model" == *"Sonnet"* ]]; then
    parts+=("${blue}sonnet-4${reset}")
elif [[ "$model" == *"Haiku"* ]]; then
    parts+=("${cyan}haiku-3.5${reset}")
else
    parts+=("${blue}${model}${reset}")
fi

# Context usage percentage (default to 0 if not present)
if [[ "$used_pct" == "null" ]] || [[ -z "$used_pct" ]]; then
    used_pct=0
fi
used_rounded=$(printf "%.0f" "$used_pct")
if [[ $used_rounded -ge 80 ]]; then
    parts+=("${dim}context:${reset}${red}${used_rounded}%${reset}")
elif [[ $used_rounded -ge 50 ]]; then
    parts+=("${dim}context:${reset}${yellow}${used_rounded}%${reset}")
else
    parts+=("${dim}context:${reset}${green}${used_rounded}%${reset}")
fi

# Join parts with separator
printf "%s" "${parts[0]}"
for ((i=1; i<${#parts[@]}; i++)); do
    printf "${dim} │ ${reset}%s" "${parts[i]}"
done
printf "\n"
