local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local function has_action(name)
  return type(wezterm.has_action) == "function" and wezterm.has_action(name)
end

local function prompt_rename_tab()
  if not has_action("PromptInputLine") then
    return act.ActivateCommandPalette
  end

  return act.PromptInputLine {
    description = "Rename current tab",
    action = wezterm.action_callback(function(window, _, line)
      if line and line ~= "" then
        window:active_tab():set_title(line)
      end
    end),
  }
end

local function prompt_rename_pane()
  if not has_action("PromptInputLine") then
    return act.ActivateCommandPalette
  end

  return act.PromptInputLine {
    description = "Rename current pane",
    action = wezterm.action_callback(function(_, pane, line)
      if line and line ~= "" and pane and pane.set_title then
        pane:set_title(line)
      end
    end),
  }
end

local function break_pane_to_tab()
  if has_action("PaneSelect") then
    return act.PaneSelect { mode = "MoveToNewTab" }
  end

  return act.SpawnTab("CurrentPaneDomain")
end

local function swap_with_active_pane()
  if has_action("PaneSelect") then
    return act.PaneSelect { mode = "SwapWithActive" }
  end

  return act.RotatePanes("Clockwise")
end

local function then_normal(next_action)
  return act.Multiple { next_action, act.PopKeyTable }
end

local split_down = act.SplitVertical { domain = "CurrentPaneDomain" }
local split_right = act.SplitHorizontal { domain = "CurrentPaneDomain" }

local mode_hud = {
  zellij_pane = {
    label = "PANE",
    hint = "h/j/k/l focus  n,d,r split  x close  f zoom",
    color = "#0EA5E9",
  },
  zellij_resize = {
    label = "RESIZE",
    hint = "h/j/k/l adjust  HJKL reverse  -/+ global",
    color = "#10B981",
  },
  zellij_tab = {
    label = "TAB",
    hint = "h/l prev-next  n new  x close  1-9 jump",
    color = "#A78BFA",
  },
  zellij_move = {
    label = "MOVE",
    hint = "n/p rotate  h/j/k/l swap",
    color = "#F59E0B",
  },
  zellij_scroll = {
    label = "SCROLL",
    hint = "j/k line  f/b page  d/u half  s search",
    color = "#F97316",
  },
  zellij_tmux = {
    label = "TMUX",
    hint = "% and \" split  c tab  n/p tab nav",
    color = "#EC4899",
  },
}

local function append_status_segment(cells, bg, fg, text)
  cells[#cells + 1] = { Background = { Color = bg } }
  cells[#cells + 1] = { Foreground = { Color = fg } }
  cells[#cells + 1] = { Text = " " .. text .. " " }
end

wezterm.on("update-right-status", function(window)
  local leader_active = window:leader_is_active()
  local active_mode = window:active_key_table()
  local mode = mode_hud[active_mode]
  local left_label = "NORMAL"
  local left_bg = "#1F2937"
  local left_fg = "#E5E7EB"

  if leader_active then
    left_label = "LEADER"
    left_bg = "#EAB308"
    left_fg = "#111827"
  end

  if mode then
    left_label = mode.label
    left_bg = mode.color
    left_fg = "#111827"
  end

  window:set_left_status(wezterm.format {
    { Background = { Color = left_bg } },
    { Foreground = { Color = left_fg } },
    { Text = " " .. left_label .. " " },
  })

  local cells = {}
  if mode then
    append_status_segment(cells, "#1F2937", "#CBD5E1", mode.hint)
  elseif leader_active then
    append_status_segment(cells, "#1F2937", "#CBD5E1", "p pane  n resize  t tab  h move  s scroll  b tmux  g cancel")
  else
    append_status_segment(cells, "#1F2937", "#94A3B8", "Ctrl+b for Zellij-style modes")
  end

  window:set_right_status(wezterm.format(cells))
end)

wezterm.on("gui-startup", function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return {
  color_scheme = "GitHub Dark",
  default_cursor_style = "SteadyUnderline",
  -- default_prog = { "zsh", "-l", "-c", "zellij -l welcome" },
  default_prog = { "zsh", "-l" },
  font = wezterm.font("Hack Nerd Font"),
  font_size = 14.0,
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = false,
  use_fancy_tab_bar = false,
  hyperlink_rules = wezterm.default_hyperlink_rules(),
  leader = { key = "b", mods = "CTRL", timeout_milliseconds = 1200 },
  keys = {
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\n") },

    -- Zellij mode keys ported to LEADER to avoid stealing shell/app Ctrl bindings.
    { key = "p", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_pane", one_shot = false } },
    { key = "n", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_resize", one_shot = false } },
    { key = "t", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_tab", one_shot = false } },
    { key = "h", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_move", one_shot = false } },
    { key = "s", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_scroll", one_shot = false } },
    { key = "o", mods = "LEADER", action = act.ShowLauncher },
    { key = "b", mods = "LEADER", action = act.ActivateKeyTable { name = "zellij_tmux", one_shot = false } },
    { key = "g", mods = "LEADER", action = act.ClearKeyTableStack },
    { key = "q", mods = "LEADER", action = act.QuitApplication },

    -- Fast paths from Zellij shared Alt bindings.
    { key = "n", mods = "ALT", action = split_right },
    { key = "h", mods = "ALT", action = act.ActivatePaneDirection("Left") },
    { key = "j", mods = "ALT", action = act.ActivatePaneDirection("Down") },
    { key = "k", mods = "ALT", action = act.ActivatePaneDirection("Up") },
    { key = "l", mods = "ALT", action = act.ActivatePaneDirection("Right") },
    { key = "i", mods = "ALT", action = act.MoveTabRelative(-1) },
    { key = "o", mods = "ALT", action = act.MoveTabRelative(1) },
    { key = "=", mods = "ALT", action = act.AdjustPaneSize { "Right", 3 } },
    { key = "-", mods = "ALT", action = act.AdjustPaneSize { "Left", 3 } },
    { key = "[", mods = "ALT", action = act.RotatePanes("CounterClockwise") },
    { key = "]", mods = "ALT", action = act.RotatePanes("Clockwise") },
  },
  key_tables = {
    zellij_pane = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "p", mods = "CTRL", action = act.PopKeyTable },

      { key = "h", mods = "NONE", action = act.ActivatePaneDirection("Left") },
      { key = "LeftArrow", mods = "NONE", action = act.ActivatePaneDirection("Left") },
      { key = "j", mods = "NONE", action = act.ActivatePaneDirection("Down") },
      { key = "DownArrow", mods = "NONE", action = act.ActivatePaneDirection("Down") },
      { key = "k", mods = "NONE", action = act.ActivatePaneDirection("Up") },
      { key = "UpArrow", mods = "NONE", action = act.ActivatePaneDirection("Up") },
      { key = "l", mods = "NONE", action = act.ActivatePaneDirection("Right") },
      { key = "RightArrow", mods = "NONE", action = act.ActivatePaneDirection("Right") },
      { key = "p", mods = "NONE", action = act.ActivatePaneDirection("Next") },

      { key = "n", mods = "NONE", action = then_normal(split_right) },
      { key = "d", mods = "NONE", action = then_normal(split_down) },
      { key = "r", mods = "NONE", action = then_normal(split_right) },
      { key = "x", mods = "NONE", action = then_normal(act.CloseCurrentPane { confirm = true }) },
      { key = "f", mods = "NONE", action = then_normal(act.TogglePaneZoomState) },
      { key = "c", mods = "NONE", action = then_normal(prompt_rename_pane()) },
    },

    zellij_resize = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "n", mods = "CTRL", action = act.PopKeyTable },

      { key = "h", mods = "NONE", action = act.AdjustPaneSize { "Left", 2 } },
      { key = "LeftArrow", mods = "NONE", action = act.AdjustPaneSize { "Left", 2 } },
      { key = "j", mods = "NONE", action = act.AdjustPaneSize { "Down", 2 } },
      { key = "DownArrow", mods = "NONE", action = act.AdjustPaneSize { "Down", 2 } },
      { key = "k", mods = "NONE", action = act.AdjustPaneSize { "Up", 2 } },
      { key = "UpArrow", mods = "NONE", action = act.AdjustPaneSize { "Up", 2 } },
      { key = "l", mods = "NONE", action = act.AdjustPaneSize { "Right", 2 } },
      { key = "RightArrow", mods = "NONE", action = act.AdjustPaneSize { "Right", 2 } },

      -- Approximation for Zellij's reverse directional resizes.
      { key = "H", mods = "SHIFT", action = act.AdjustPaneSize { "Right", 2 } },
      { key = "J", mods = "SHIFT", action = act.AdjustPaneSize { "Up", 2 } },
      { key = "K", mods = "SHIFT", action = act.AdjustPaneSize { "Down", 2 } },
      { key = "L", mods = "SHIFT", action = act.AdjustPaneSize { "Left", 2 } },
      { key = "=", mods = "NONE", action = act.Multiple { act.AdjustPaneSize { "Right", 1 }, act.AdjustPaneSize { "Down", 1 } } },
      { key = "+", mods = "SHIFT", action = act.Multiple { act.AdjustPaneSize { "Right", 1 }, act.AdjustPaneSize { "Down", 1 } } },
      { key = "-", mods = "NONE", action = act.Multiple { act.AdjustPaneSize { "Left", 1 }, act.AdjustPaneSize { "Up", 1 } } },
    },

    zellij_tab = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "t", mods = "CTRL", action = act.PopKeyTable },

      { key = "r", mods = "NONE", action = then_normal(prompt_rename_tab()) },
      { key = "h", mods = "NONE", action = act.ActivateTabRelative(-1) },
      { key = "LeftArrow", mods = "NONE", action = act.ActivateTabRelative(-1) },
      { key = "UpArrow", mods = "NONE", action = act.ActivateTabRelative(-1) },
      { key = "k", mods = "NONE", action = act.ActivateTabRelative(-1) },
      { key = "l", mods = "NONE", action = act.ActivateTabRelative(1) },
      { key = "RightArrow", mods = "NONE", action = act.ActivateTabRelative(1) },
      { key = "DownArrow", mods = "NONE", action = act.ActivateTabRelative(1) },
      { key = "j", mods = "NONE", action = act.ActivateTabRelative(1) },

      { key = "n", mods = "NONE", action = then_normal(act.SpawnTab("CurrentPaneDomain")) },
      { key = "x", mods = "NONE", action = then_normal(act.CloseCurrentTab { confirm = true }) },
      { key = "b", mods = "NONE", action = then_normal(break_pane_to_tab()) },
      { key = "[", mods = "NONE", action = then_normal(act.MoveTabRelative(-1)) },
      { key = "]", mods = "NONE", action = then_normal(act.MoveTabRelative(1)) },
      { key = "Tab", mods = "NONE", action = act.ActivateLastTab },

      { key = "1", mods = "NONE", action = then_normal(act.ActivateTab(0)) },
      { key = "2", mods = "NONE", action = then_normal(act.ActivateTab(1)) },
      { key = "3", mods = "NONE", action = then_normal(act.ActivateTab(2)) },
      { key = "4", mods = "NONE", action = then_normal(act.ActivateTab(3)) },
      { key = "5", mods = "NONE", action = then_normal(act.ActivateTab(4)) },
      { key = "6", mods = "NONE", action = then_normal(act.ActivateTab(5)) },
      { key = "7", mods = "NONE", action = then_normal(act.ActivateTab(6)) },
      { key = "8", mods = "NONE", action = then_normal(act.ActivateTab(7)) },
      { key = "9", mods = "NONE", action = then_normal(act.ActivateTab(8)) },
    },

    zellij_move = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "h", mods = "CTRL", action = act.PopKeyTable },

      -- WezTerm has no directional move-pane action; this is the nearest equivalent.
      { key = "n", mods = "NONE", action = act.RotatePanes("Clockwise") },
      { key = "Tab", mods = "NONE", action = act.RotatePanes("Clockwise") },
      { key = "p", mods = "NONE", action = act.RotatePanes("CounterClockwise") },
      { key = "h", mods = "NONE", action = swap_with_active_pane() },
      { key = "LeftArrow", mods = "NONE", action = swap_with_active_pane() },
      { key = "j", mods = "NONE", action = swap_with_active_pane() },
      { key = "DownArrow", mods = "NONE", action = swap_with_active_pane() },
      { key = "k", mods = "NONE", action = swap_with_active_pane() },
      { key = "UpArrow", mods = "NONE", action = swap_with_active_pane() },
      { key = "l", mods = "NONE", action = swap_with_active_pane() },
      { key = "RightArrow", mods = "NONE", action = swap_with_active_pane() },
    },

    zellij_scroll = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "s", mods = "CTRL", action = act.PopKeyTable },
      { key = "e", mods = "NONE", action = act.ActivateCopyMode },
      { key = "s", mods = "NONE", action = act.Search("CurrentSelectionOrEmptyString") },
      { key = "c", mods = "CTRL", action = act.Multiple { act.ScrollToBottom, act.PopKeyTable } },
      { key = "j", mods = "NONE", action = act.ScrollByLine(1) },
      { key = "DownArrow", mods = "NONE", action = act.ScrollByLine(1) },
      { key = "k", mods = "NONE", action = act.ScrollByLine(-1) },
      { key = "UpArrow", mods = "NONE", action = act.ScrollByLine(-1) },
      { key = "f", mods = "CTRL", action = act.ScrollByPage(1) },
      { key = "PageDown", mods = "NONE", action = act.ScrollByPage(1) },
      { key = "RightArrow", mods = "NONE", action = act.ScrollByPage(1) },
      { key = "l", mods = "NONE", action = act.ScrollByPage(1) },
      { key = "b", mods = "CTRL", action = act.ScrollByPage(-1) },
      { key = "PageUp", mods = "NONE", action = act.ScrollByPage(-1) },
      { key = "LeftArrow", mods = "NONE", action = act.ScrollByPage(-1) },
      { key = "h", mods = "NONE", action = act.ScrollByPage(-1) },
      { key = "d", mods = "NONE", action = act.ScrollByLine(10) },
      { key = "u", mods = "NONE", action = act.ScrollByLine(-10) },
    },

    zellij_tmux = {
      { key = "Enter", mods = "NONE", action = act.PopKeyTable },
      { key = "Escape", mods = "NONE", action = act.PopKeyTable },
      { key = "[", mods = "NONE", action = then_normal(act.ActivateCopyMode) },
      { key = "b", mods = "CTRL", action = then_normal(act.SendKey { key = "b", mods = "CTRL" }) },
      { key = "\"", mods = "NONE", action = then_normal(split_down) },
      { key = "%", mods = "NONE", action = then_normal(split_right) },
      { key = "z", mods = "NONE", action = then_normal(act.TogglePaneZoomState) },
      { key = "c", mods = "NONE", action = then_normal(act.SpawnTab("CurrentPaneDomain")) },
      { key = ",", mods = "NONE", action = then_normal(prompt_rename_tab()) },
      { key = "p", mods = "NONE", action = then_normal(act.ActivateTabRelative(-1)) },
      { key = "n", mods = "NONE", action = then_normal(act.ActivateTabRelative(1)) },
      { key = "LeftArrow", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Left")) },
      { key = "RightArrow", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Right")) },
      { key = "DownArrow", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Down")) },
      { key = "UpArrow", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Up")) },
      { key = "h", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Left")) },
      { key = "l", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Right")) },
      { key = "j", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Down")) },
      { key = "k", mods = "NONE", action = then_normal(act.ActivatePaneDirection("Up")) },
      { key = "o", mods = "NONE", action = act.ActivatePaneDirection("Next") },
      { key = "d", mods = "NONE", action = then_normal(act.Hide) },
      { key = "Space", mods = "NONE", action = act.RotatePanes("Clockwise") },
      { key = "x", mods = "NONE", action = then_normal(act.CloseCurrentPane { confirm = true }) },
    },
  },
  quit_when_all_windows_are_closed = true,
  window_close_confirmation = "NeverPrompt",
}
