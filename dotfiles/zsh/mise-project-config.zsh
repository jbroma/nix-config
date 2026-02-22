# Keep project-specific mise config outside repos by deriving a stable
# per-project filename under ~/.config/mise/projects.
_mise_set_project_config() {
  local project_root project_key project_dir
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
  project_key="$(printf '%s' "$project_root" | shasum -a 256 | cut -d' ' -f1)"
  project_dir="$HOME/.config/mise/projects"
  mkdir -p "$project_dir"

  # First path is where `mise use` writes; second keeps repo tasks discoverable.
  export MISE_OVERRIDE_CONFIG_FILENAMES="$project_dir/$project_key.toml:mise.toml"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _mise_set_project_config
_mise_set_project_config
