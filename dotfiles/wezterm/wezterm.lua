local wezterm = require("wezterm")

return {
  default_prog = { "zsh", "-l", "-c", "zellij -l welcome" },
  font = wezterm.font("Hack Nerd Font"),
  font_size = 14.0,
  hide_tab_bar_if_only_one_tab = true,
  window_close_confirmation = "NeverPrompt",
}
