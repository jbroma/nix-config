# Worktrunk bare-repo clone interceptors.
# Converts simple clone commands into:
#   <repo>/.git   (bare)
#   <repo>/<default-branch> (first worktree via wt switch ^)

_wt_clone_repo_name() {
  local clone_target="$1"
  local trimmed_target=""
  local repo_name=""

  trimmed_target="$(printf '%s' "$clone_target" | sed 's:/*$::')"
  repo_name="$(basename "$trimmed_target")"
  printf '%s\n' "$repo_name" | sed 's/\.git$//'
}

_wt_bootstrap_first_worktree() {
  local repo_dir="$1"

  if ! command -v wt >/dev/null 2>&1; then
    echo "warning: wt is not installed; run: cd $repo_dir && wt switch ^" >&2
    return 0
  fi

  # Create the default-branch worktree for bare-repo layout.
  if ! command wt -C "$repo_dir" switch '^' --no-cd; then
    echo "warning: clone succeeded but worktree bootstrap failed; run: cd $repo_dir && wt switch ^" >&2
  fi
}

_wt_clone_target_guard() {
  local repo_dir="$1"

  if [ -e "$repo_dir/.git" ]; then
    echo "error: $repo_dir/.git already exists" >&2
    return 1
  fi

  if [ -e "$repo_dir" ] && [ -n "$(command ls -A "$repo_dir" 2>/dev/null)" ]; then
    echo "error: $repo_dir exists and is not empty" >&2
    return 1
  fi
}

_wt_clone_passthrough() {
  local clone_backend="$1"
  shift

  if [ "$clone_backend" = "gh" ]; then
    command gh repo clone "$@"
    return $?
  fi

  command git clone "$@"
}

_wt_clone_bare_layout() {
  local clone_backend="$1"
  local repo_ref=""
  local repo_dir=""
  shift

  repo_ref="$1"
  repo_dir="$2"

  # Keep native behavior for anything beyond simple: clone <repo> [dir]
  if [ -z "$repo_ref" ] || [ -n "$3" ]; then
    _wt_clone_passthrough "$clone_backend" "$@"
    return $?
  fi

  case "$repo_ref" in
    -*)
      _wt_clone_passthrough "$clone_backend" "$@"
      return $?
      ;;
  esac

  case "$repo_dir" in
    -*)
      _wt_clone_passthrough "$clone_backend" "$@"
      return $?
      ;;
  esac

  if [ -z "$repo_dir" ]; then
    repo_dir="$(_wt_clone_repo_name "$repo_ref")"
  fi

  _wt_clone_target_guard "$repo_dir" || return 1
  mkdir -p "$repo_dir" || return 1

  if [ "$clone_backend" = "gh" ]; then
    command gh repo clone "$repo_ref" "$repo_dir/.git" -- --bare || return $?
  else
    command git clone --bare "$repo_ref" "$repo_dir/.git" || return $?
  fi

  _wt_bootstrap_first_worktree "$repo_dir"
}

git() {
  if [ "$1" = "clone" ]; then
    shift
    _wt_clone_bare_layout git "$@"
    return $?
  fi

  command git "$@"
}

gh() {
  if [ "$1" = "clone" ]; then
    shift
    _wt_clone_bare_layout gh "$@"
    return $?
  fi

  if [ "$1" = "repo" ] && [ "$2" = "clone" ]; then
    shift
    shift
    _wt_clone_bare_layout gh "$@"
    return $?
  fi

  command gh "$@"
}
