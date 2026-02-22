# Keep project-specific mise config outside repos by deriving a stable
# per-project filename under ~/.config/mise/projects.
_mise_set_project_config() {
  local project_root project_key project_dir relative_path
  project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"

  if [[ "$project_root" == "$HOME" ]]; then
    relative_path="home"
  elif [[ "$project_root" == "$HOME/"* ]]; then
    relative_path="${project_root#$HOME/}"
  else
    # Keep non-home paths flat as well.
    relative_path="${project_root#/}"
  fi

  project_key="${relative_path//\//-}"
  project_key="${project_key// /-}"
  if [[ -z "$project_key" ]]; then
    project_key="root"
  fi

  project_dir="$HOME/.config/mise/projects"
  mkdir -p "$project_dir"

  # First path is where `mise use` writes; second keeps repo tasks discoverable.
  export MISE_OVERRIDE_CONFIG_FILENAMES="$project_dir/$project_key.toml:mise.toml"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _mise_set_project_config
_mise_set_project_config
