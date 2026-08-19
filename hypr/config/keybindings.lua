-- Ported from the old flake's hyprland.lua. Dropped: DankMaterialShell IPC
-- bindings (launcher, process list - no shell/launcher is installed here),
-- the `nos rebuild/update/switch/install/remove` bindings (that CLI doesn't
-- exist in this config), and the `uwsm app --` exec wrapper (no UWSM here,
-- commands run directly). Volume/mic bindings now call wpctl directly
-- instead of going through DMS.
local monitors = require("config.monitors")

local function send_shortcut_once(mods, key)
	return function()
		hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
		hl.timer(function()
			hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
		end, { timeout = 50, type = "oneshot" })
	end
end

local function active_window_is_terminal()
	local window = hl.get_active_window()
	if not window then
		return false
	end

	for _, tag in ipairs(window.tags or {}) do
		if tag:gsub("%*$", "") == "terminal" then
			return true
		end
	end

	return window.class == "kitty"
end

local function universal_clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
	local default_shortcut = send_shortcut_once(default_mods, default_key)
	local terminal_shortcut = send_shortcut_once(terminal_mods, terminal_key)

	return function()
		if active_window_is_terminal() then
			terminal_shortcut()
		else
			default_shortcut()
		end
	end
end

local function open_workspace_terminal()
	if active_window_is_terminal() then
		send_shortcut_once("CTRL SHIFT", "F12")()
	else
		hl.dispatch(hl.dsp.exec_cmd("kitty"))
	end
end

local function bind(keys, description, dispatcher, options)
	assert(description and description ~= "", "Keybind description is required for " .. keys)
	options = options or {}
	options.desc = description
	return hl.bind(keys, dispatcher, options)
end

local screenshot_command = 'mkdir -p ~/Screenshots && file="$HOME/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png" && grim -g "$(slurp)" "$file" && wl-copy --type image/png < "$file"'

local scroll_next = function() monitors.scroll_workspace(1) end
local scroll_prev = function() monitors.scroll_workspace(-1) end

bind("XF86PowerOff", "Suspend system", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })
bind("switch:on:Lid Switch", "Suspend when lid closes", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

bind("SUPER + S", "Toggle terminal workspace", hl.dsp.workspace.toggle_special("terminal"))
bind("SUPER + E", "Open file manager", hl.dsp.exec_cmd("nautilus"))
bind("SUPER + Return", "Open terminal", open_workspace_terminal)
bind("SUPER + W", "Close active window", hl.dsp.window.close())
bind("SUPER + J", "Toggle split direction", hl.dsp.layout("togglesplit"))
bind("SUPER + T", "Toggle floating window", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + F", "Toggle fullscreen window", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + Tab", "Focus previous workspace", hl.dsp.focus({ workspace = "previous" }))
bind("SUPER + mouse_up", "Focus next workspace", scroll_next)
bind("SUPER + mouse_down", "Focus previous workspace", scroll_prev)

bind("SUPER + left", "Focus window left", hl.dsp.focus({ direction = "left" }))
bind("SUPER + right", "Focus window right", hl.dsp.focus({ direction = "right" }))
bind("SUPER + up", "Focus window up", hl.dsp.focus({ direction = "up" }))
bind("SUPER + down", "Focus window down", hl.dsp.focus({ direction = "down" }))
bind("SUPER + SHIFT + left", "Move window left", hl.dsp.window.move({ direction = "left" }))
bind("SUPER + SHIFT + right", "Move window right", hl.dsp.window.move({ direction = "right" }))
bind("SUPER + SHIFT + up", "Move window up", hl.dsp.window.move({ direction = "up" }))
bind("SUPER + SHIFT + down", "Move window down", hl.dsp.window.move({ direction = "down" }))

bind("SUPER + 1", "Focus workspace 1", hl.dsp.focus({ workspace = 1 }))
bind("SUPER + 2", "Focus workspace 2", hl.dsp.focus({ workspace = 2 }))
bind("SUPER + 3", "Focus workspace 3", hl.dsp.focus({ workspace = 3 }))
bind("SUPER + 4", "Focus workspace 4", hl.dsp.focus({ workspace = 4 }))
bind("SUPER + 5", "Focus workspace 5", hl.dsp.focus({ workspace = 5 }))
bind("SUPER + 6", "Focus workspace 6", hl.dsp.focus({ workspace = 6 }))
bind("SUPER + 7", "Focus workspace 7", hl.dsp.focus({ workspace = 7 }))
bind("SUPER + 8", "Focus workspace 8", hl.dsp.focus({ workspace = 8 }))
bind("SUPER + 9", "Focus workspace 9", hl.dsp.focus({ workspace = 9 }))

bind("SUPER + SHIFT + 1", "Move window to workspace 1", hl.dsp.window.move({ workspace = 1 }))
bind("SUPER + SHIFT + 2", "Move window to workspace 2", hl.dsp.window.move({ workspace = 2 }))
bind("SUPER + SHIFT + 3", "Move window to workspace 3", hl.dsp.window.move({ workspace = 3 }))
bind("SUPER + SHIFT + 4", "Move window to workspace 4", hl.dsp.window.move({ workspace = 4 }))
bind("SUPER + SHIFT + 5", "Move window to workspace 5", hl.dsp.window.move({ workspace = 5 }))
bind("SUPER + SHIFT + 6", "Move window to workspace 6", hl.dsp.window.move({ workspace = 6 }))
bind("SUPER + SHIFT + 7", "Move window to workspace 7", hl.dsp.window.move({ workspace = 7 }))
bind("SUPER + SHIFT + 8", "Move window to workspace 8", hl.dsp.window.move({ workspace = 8 }))
bind("SUPER + SHIFT + 9", "Move window to workspace 9", hl.dsp.window.move({ workspace = 9 }))
bind("SUPER + SHIFT + S", "Move window to special workspace", hl.dsp.window.move({ workspace = "special:terminal" }))

bind("SUPER + equal", "Increase window width", hl.dsp.window.resize({ x = 75, y = 0, relative = true }), { repeating = true })
bind("SUPER + minus", "Decrease window width", hl.dsp.window.resize({ x = -75, y = 0, relative = true }), { repeating = true })
bind("SUPER + mouse:272", "Drag window", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
bind("SUPER + SHIFT + K", "Pick screen colour and copy hex code", hl.dsp.exec_cmd("hyprpicker --autocopy --format=hex --lowercase-hex"))
bind("PRINT", "Capture screen region", hl.dsp.exec_cmd(screenshot_command))

bind("SUPER + X", "Universal cut", send_shortcut_once("CTRL", "X"))
bind("SUPER + C", "Universal copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
bind("SUPER + V", "Universal paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

bind("XF86AudioRaiseVolume", "Raise audio volume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", "Lower audio volume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
bind("XF86AudioMute", "Toggle audio mute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
bind("XF86AudioMicMute", "Toggle microphone mute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

bind("XF86MonBrightnessUp", "Raise display brightness", hl.dsp.exec_cmd("brightnessctl --quiet --class=backlight set +5%"), { locked = true, repeating = true })
bind("XF86MonBrightnessDown", "Lower display brightness", hl.dsp.exec_cmd("brightnessctl --quiet --class=backlight set 5%-"), { locked = true, repeating = true })

bind("SUPER + M", "Toggle single-window max width", monitors.toggle_aspect_ratio)
