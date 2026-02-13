local wezterm = require("wezterm")
local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return {
  color_scheme = "GitHub Dark",
  default_cursor_style = "SteadyUnderline",
  default_prog = { "zsh", "-l", "-c", "zellij -l welcome" },
  font = wezterm.font("Hack Nerd Font"),
  font_size = 14.0,
  hide_tab_bar_if_only_one_tab = true,
  hyperlink_rules = wezterm.default_hyperlink_rules(),
  keys = {
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },
  },
  quit_when_all_windows_are_closed = true,
  window_close_confirmation = "NeverPrompt",
}
