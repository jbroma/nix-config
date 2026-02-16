local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local spawn_tab
local pane_id

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

  return spawn_tab
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
spawn_tab = act.SpawnTab("CurrentPaneDomain")
local function defer(seconds, fn)
  if wezterm.time and wezterm.time.call_after then
    wezterm.time.call_after(seconds, fn)
    return
  end

  fn()
end

local function tab_panes_with_info(tab)
  if not tab or not tab.panes_with_info then
    return nil
  end

  local ok_panes, panes = pcall(function()
    return tab:panes_with_info()
  end)
  if not ok_panes then
    return nil
  end

  return panes
end

pane_id = function(pane)
  if not pane or not pane.pane_id then
    return nil
  end

  local ok_id, id = pcall(function()
    return pane:pane_id()
  end)
  if ok_id then
    return id
  end

  return nil
end

local function panes_on_split_side(tab, anchor_pane)
  local panes = tab_panes_with_info(tab)
  if not panes or #panes < 2 then
    return nil
  end

  local anchor_id = pane_id(anchor_pane)
  local anchor = nil

  for _, info in ipairs(panes) do
    if anchor_id and pane_id(info.pane) == anchor_id then
      anchor = info
      break
    end

    if not anchor and info.is_active then
      anchor = info
    end
  end

  if not anchor then
    return nil
  end

  local tolerance = 1
  local side = {}
  for _, info in ipairs(panes) do
    if math.abs(info.top - anchor.top) <= tolerance and math.abs(info.height - anchor.height) <= tolerance then
      side[#side + 1] = info
    end
  end

  if #side < 2 then
    return nil
  end

  table.sort(side, function(a, b)
    if a.left == b.left then
      return (a.index or 0) < (b.index or 0)
    end
    return a.left < b.left
  end)

  return side
end

local function rebalance_vertical_side(window, tab, anchor_pane)
  local initial = panes_on_split_side(tab, anchor_pane)
  if not initial then
    return
  end

  local count = #initial
  local left = initial[1].left
  local right = initial[count].left + initial[count].width
  local total_width = right - left
  if total_width <= 0 then
    return
  end

  for boundary = 1, count - 1 do
    local current = panes_on_split_side(tab, anchor_pane)
    if not current or #current ~= count then
      return
    end

    local current_boundary = current[boundary + 1].left
    local desired_boundary = left + math.floor((total_width * boundary) / count)
    local delta = current_boundary - desired_boundary
    if delta ~= 0 then
      local amount = math.abs(delta)
      local target_pane = nil
      local direction = nil

      if delta > 0 then
        -- Boundary is too far right; move it left by expanding the pane on the right to the left.
        target_pane = current[boundary + 1].pane
        direction = "Left"
      else
        -- Boundary is too far left; move it right by expanding the pane on the left to the right.
        target_pane = current[boundary].pane
        direction = "Right"
      end

      if target_pane and direction then
        window:perform_action(act.AdjustPaneSize { direction, amount }, target_pane)
      end
    end
  end
end

local split_adaptive = wezterm.action_callback(function(window, pane)
  local action = split_down
  local rebalance_after = false
  local ok_tab, tab = pcall(function()
    return pane:tab()
  end)

  if ok_tab and tab and tab.panes_with_info then
    local ok_panes, panes = pcall(function()
      return tab:panes_with_info()
    end)
    if ok_panes and panes and #panes <= 1 then
      action = split_right
    else
      rebalance_after = true
    end
  end

  window:perform_action(action, pane)

  if rebalance_after and ok_tab and tab then
    defer(0.01, function()
      rebalance_vertical_side(window, tab, pane)
    end)
  end
end)

local glass = {
  base_bg = "#101216",
  title_bg = "#101216",
  title_inactive_bg = "#101216",
  panel_fg = "#DCE7FF",
  muted_fg = "#90A4CA",
  normal_bg = "#1A253A",
  tab_bar_bg = "#101216",
  tab_active_bg = "#2A3B5E",
  tab_active_fg = "#E8EFFF",
  tab_inactive_bg = "#151F31",
  tab_inactive_fg = "#8FA4CC",
  tab_hover_bg = "#22314F",
  leader_bg = "#79AEFF",
  pane_border = "#2A3448",
}

local mode_hud = {
  zellij_pane = {
    label = "PANE",
    hint = "h/j/k/l focus  p next  n auto-split  d/r split",
    color = "#7AA2F7",
  },
  zellij_resize = {
    label = "RESIZE",
    hint = "h/j/k/l adjust  HJKL reverse  -/+ global",
    color = "#73DACA",
  },
  zellij_tab = {
    label = "TAB",
    hint = "h/l prev-next  n new  x close  1-9 jump",
    color = "#E0AF68",
  },
  zellij_move = {
    label = "MOVE",
    hint = "n/p rotate  h/j/k/l swap",
    color = "#F7768E",
  },
  zellij_scroll = {
    label = "SCROLL",
    hint = "j/k line  f/b page  d/u half  s search",
    color = "#7DCFFF",
  },
}

local rounded = {
  left = "",
  right = "",
}

if wezterm.nerdfonts then
  rounded.left = wezterm.nerdfonts.ple_left_half_circle_thick or rounded.left
  rounded.right = wezterm.nerdfonts.ple_right_half_circle_thick or rounded.right
end

local function append_pill(cells, surface_bg, pill_bg, pill_fg, text, opts)
  opts = opts or {}
  local left_cap = opts.left_cap ~= false
  local right_cap = opts.right_cap ~= false
  local spacer = opts.spacer
  local fixed_width = opts.fixed_width
  local align = opts.align or "left"
  local center_bias = opts.center_bias or 0
  if spacer == nil then
    spacer = " "
  end

  if fixed_width and #text < fixed_width then
    local padding = fixed_width - #text
    if align == "center" then
      local left_padding = math.floor(padding / 2) + center_bias
      if left_padding < 0 then
        left_padding = 0
      elseif left_padding > padding then
        left_padding = padding
      end
      local right_padding = padding - left_padding
      text = string.rep(" ", left_padding) .. text .. string.rep(" ", right_padding)
    else
      text = text .. string.rep(" ", padding)
    end
  end

  cells[#cells + 1] = { Background = { Color = surface_bg } }
  if left_cap then
    cells[#cells + 1] = { Foreground = { Color = pill_bg } }
    cells[#cells + 1] = { Text = rounded.left }
  end

  cells[#cells + 1] = { Background = { Color = pill_bg } }
  cells[#cells + 1] = { Foreground = { Color = pill_fg } }
  cells[#cells + 1] = { Text = " " .. text .. " " }

  if right_cap then
    cells[#cells + 1] = { Background = { Color = surface_bg } }
    cells[#cells + 1] = { Foreground = { Color = pill_bg } }
    cells[#cells + 1] = { Text = rounded.right }
  end

  cells[#cells + 1] = { Background = { Color = surface_bg } }
  cells[#cells + 1] = { Foreground = { Color = surface_bg } }
  cells[#cells + 1] = { Text = spacer }
end

local function trim(text)
  if not text then
    return nil
  end

  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(path)
  if not path then
    return nil
  end

  return path:gsub(".*[/\\]", "")
end

local function simplify_pane_title(title)
  local value = trim(title)
  if not value or value == "" then
    return nil
  end

  if value:find("|", 1, true) then
    value = trim(value:match("([^|]+)$"))
  end

  return value
end

local function active_app_name(pane)
  if pane then
    local ok_name, process_path = pcall(function()
      return pane:get_foreground_process_name()
    end)
    if ok_name and process_path and process_path ~= "" then
      local name = basename(process_path)
      if name and name ~= "" then
        return name:gsub("%.exe$", "")
      end
    end

    local ok_title, pane_title = pcall(function()
      return pane:get_title()
    end)
    if ok_title then
      local title = simplify_pane_title(pane_title)
      if title and title ~= "" then
        return title
      end
    end
  end

  return "wezterm"
end

wezterm.on("format-window-title", function(_, pane, _, _, _)
  return active_app_name(pane)
end)

wezterm.on("format-tab-title", function(tab, _, _, _, hover, max_width)
  local tab_bg = glass.tab_inactive_bg
  local tab_fg = glass.tab_inactive_fg

  if tab.is_active then
    tab_bg = glass.tab_active_bg
    tab_fg = glass.tab_active_fg
  elseif hover then
    tab_bg = glass.tab_hover_bg
    tab_fg = glass.panel_fg
  end

  local tab_index = tab and tab.tab_index or 0
  local label = "Tab " .. tostring(tab_index + 1)
  local text = wezterm.truncate_right(label, math.max((max_width or 24) - 4, 1))
  local cells = {}
  append_pill(cells, glass.tab_bar_bg, tab_bg, tab_fg, text)
  return cells
end)

wezterm.on("update-right-status", function(window)
  local leader_active = window:leader_is_active()
  local active_mode = window:active_key_table()
  local mode = mode_hud[active_mode]
  local left_label = "NORMAL"
  local left_bg = glass.normal_bg
  local left_fg = glass.panel_fg

  if leader_active then
    left_label = "LEADER"
    left_bg = glass.leader_bg
    left_fg = "#08111F"
  end

  if mode then
    left_label = mode.label
    left_bg = mode.color
    left_fg = "#08111F"
  end

  local left_cells = {}
  append_pill(left_cells, glass.tab_bar_bg, left_bg, left_fg, left_label, {
    left_cap = false,
    fixed_width = 8,
    align = "center",
    center_bias = 1,
  })
  window:set_left_status(wezterm.format(left_cells))

  local cells = {}
  if mode then
    append_pill(cells, glass.tab_bar_bg, mode.color, "#08111F", mode.hint, { right_cap = false, spacer = "" })
  elseif leader_active then
    append_pill(cells, glass.tab_bar_bg, glass.leader_bg, "#08111F", "p pane  n resize  t tab  h move  s scroll  g cancel", { right_cap = false, spacer = "" })
  else
    append_pill(cells, glass.tab_bar_bg, glass.normal_bg, glass.muted_fg, "p pane  n resize  t tab  h move  s scroll", { right_cap = false, spacer = "" })
  end

  window:set_right_status(wezterm.format(cells))
end)

wezterm.on("gui-startup", function(cmd)
  local _, _, window = mux.spawn_window(cmd or {})
  local gui_window = window:gui_window()
  if not gui_window then
    return
  end

  local screen = nil
  if wezterm.gui and wezterm.gui.screens then
    local ok_screens, screens = pcall(function()
      return wezterm.gui.screens()
    end)
    if ok_screens and screens and screens.active then
      screen = screens.active
    end
  end

  if screen and screen.width and screen.height then
    local ok_resize = pcall(function()
      gui_window:set_position(screen.x or 0, screen.y or 0)
      gui_window:set_inner_size(screen.width, screen.height)
    end)
    if not ok_resize then
      gui_window:maximize()
    end
  else
    gui_window:maximize()
  end
end)

return {
  color_scheme = "GitHub Dark",
  colors = {
    background = glass.base_bg,
    split = glass.pane_border,
    tab_bar = {
      background = glass.tab_bar_bg,
      active_tab = {
        bg_color = glass.tab_active_bg,
        fg_color = glass.tab_active_fg,
        intensity = "Bold",
      },
      inactive_tab = {
        bg_color = glass.tab_inactive_bg,
        fg_color = glass.tab_inactive_fg,
      },
      inactive_tab_hover = {
        bg_color = glass.tab_hover_bg,
        fg_color = glass.tab_inactive_fg,
        italic = false,
      },
      new_tab = {
        bg_color = glass.tab_bar_bg,
        fg_color = glass.muted_fg,
      },
      new_tab_hover = {
        bg_color = glass.normal_bg,
        fg_color = glass.panel_fg,
        italic = false,
      },
    },
  },
  window_background_opacity = 1.0,
  text_background_opacity = 1.0,
  macos_window_background_blur = 0,
  inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.78,
  },
  default_cursor_style = "SteadyUnderline",
  -- default_prog = { "zsh", "-l", "-c", "zellij -l welcome" },
  default_prog = { "zsh", "-l" },
  font = wezterm.font("Hack Nerd Font"),
  font_size = 14.0,
  window_padding = {
    left = 8,
    right = 8,
    top = 6,
    bottom = 4,
  },
  window_decorations = "TITLE|RESIZE|MACOS_USE_BACKGROUND_COLOR_AS_TITLEBAR_COLOR",
  window_frame = {
    font = wezterm.font_with_fallback {
      { family = "SF Pro Display", weight = "Bold" },
      { family = "SF Pro Text", weight = "Bold" },
      { family = "Helvetica Neue", weight = "Bold" },
      { family = "Arial", weight = "Bold" },
      { family = "Hack Nerd Font", weight = "Bold" },
    },
    font_size = 12.0,
    active_titlebar_bg = glass.title_bg,
    inactive_titlebar_bg = glass.title_inactive_bg,
    active_titlebar_border_bottom = glass.pane_border,
    inactive_titlebar_border_bottom = glass.pane_border,
  },
  hide_tab_bar_if_only_one_tab = false,
  tab_bar_at_bottom = false,
  use_fancy_tab_bar = false,
  show_new_tab_button_in_tab_bar = false,
  mouse_wheel_scrolls_tabs = false,
  swallow_mouse_click_on_pane_focus = true,
  swallow_mouse_click_on_window_focus = true,
  tab_max_width = 56,
  hyperlink_rules = wezterm.default_hyperlink_rules(),
  mouse_bindings = {
    -- Prevent accidental link opens on plain click.
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = act.CompleteSelection("ClipboardAndPrimarySelection"),
    },
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "CMD",
      action = act.OpenLinkAtMouseCursor,
    },
    {
      event = { Down = { streak = 1, button = "Left" } },
      mods = "CMD",
      action = act.Nop,
    },
  },
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

      { key = "n", mods = "NONE", action = then_normal(split_adaptive) },
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

      { key = "n", mods = "NONE", action = then_normal(spawn_tab) },
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

  },
  quit_when_all_windows_are_closed = true,
  window_close_confirmation = "NeverPrompt",
}
