-- =============================================================================
-- CORE SETTINGS
-- =============================================================================

hl.config({
	input = {
		sensitivity = 0.2,
		repeat_rate = 35,
		repeat_delay = 200,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.5,
		},
	},
	binds = { scroll_event_delay = 0 },
	cursor = { no_hardware_cursors = true },
	general = {
		gaps_in = 4,
		gaps_out = 8,
		border_size = 0,
		layout = "dwindle",
	},
	decoration = {
		rounding = 3,
		active_opacity = 0.98,
		inactive_opacity = 0.96,
		blur = { enabled = true, xray = true, special = true, passes = 2, size = 3 },
		shadow = {
			enabled = true,
			range = 30,
			render_power = 50,
			color = 0x33000000,
			color_inactive = 0x22000000,
			offset = { 0, 4 },
		},
	},
	animations = { enabled = true },
	layout = { single_window_aspect_ratio = { 16, 9 } },
	
	dwindle = {
		preserve_split = true,
		smart_split = false,
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		focus_on_activate = true,
	},
})

-- =============================================================================
-- ANIMATIONS
-- =============================================================================

hl.curve("spring", {
	type = "spring",
	mass = 1,
	stiffness = 30000,
	dampening = 1000,
})

hl.curve("fast", {
	type = "bezier",
	points = { { 0.05, 0.7 }, { 0.1, 1.0 } },
})

local animations = {
	{ enabled = false, leaf = "workspaces", speed = 0.1, spring = "spring" },
	{ enabled = true, leaf = "windows", speed = 0.1, spring = "spring" },
	{ enabled = false, leaf = "windowsOut", speed = 0.1, spring = "spring" },
	{ enabled = false, leaf = "specialWorkspace", speed = 1.5, bezier = "fast", style = "slidevert" },
	{ enabled = true, leaf = "fade", speed = 4, bezier = "fast" },
}

for _, animation in ipairs(animations) do
	hl.animation(animation)
end

-- =============================================================================
-- LAYER RULES
-- =============================================================================

-- Quickshell launcher stays mapped with an empty input region while closed.
-- Keep layer animations disabled so opacity changes remain immediate.
local quickshell_layers = { "quickshell:bar", "quickshell:launcher" }

for _, namespace in ipairs(quickshell_layers) do
	hl.layer_rule({
		match = { namespace = "^" .. namespace .. "$" },
		no_anim = true,
	})
end

-- =============================================================================
-- WINDOW RULES
-- =============================================================================

-- Generic float/center rules for picker-style windows.
local picker_windows = {
	{ class = "xdg-desktop-portal-gtk" },
	{ title = "termfilechooser" },
}

for _, window in ipairs(picker_windows) do
	hl.window_rule({
		match = window.title and { title = window.title } or { class = window.class },
		float = true,
		center = true,
		size = window.size or { 1300, 800 },
	})
end

hl.window_rule({
	name = "gnome-calculator",
	match = { class = "^org.gnome.Calculator$" },
	float = true,
	size = { 360, 616 },
})

hl.window_rule({
    -- Matches any window that is in a floating state
    match = { float = true },
    
    -- "0.85 override" forces it to stay exactly at 85% opacity,
    -- bypassing the global active_opacity and inactive_opacity.
    -- Format: "active_opacity inactive_opacity fullscreen_opacity"
    opacity = "0.99 override 0.98 override 1.0 override",
})

-- =============================================================================
-- MONITORS AND WORKSPACES
-- =============================================================================

-- Static monitor list for this machine (Legion laptop, built-in display only).
-- Add entries for external monitors as needed.
local configured_monitors = {
	{
		output = "eDP-1",
		mode = "1920x1080@60",
		position = "0x0",
		scale = 1,
		workspaces = { 1, 2, 3 },
	},
	{
		output = "HDMI-A-1",
		mode = "3440x1440@59.96Hz",
		position = "1920x0",
		scale = 1,
		workspaces = { 4, 5, 6, 7, 8, 9 },
	},
}

local all_workspaces = {}
local workspace_scroll
local aspect_ratio_enabled = true

local function assign_workspaces(monitor, workspaces)
	for _, workspace in ipairs(workspaces) do
		table.insert(all_workspaces, workspace)
		hl.workspace_rule({
			workspace = tostring(workspace),
			monitor = monitor,
			default = true,
			persistent = true,
		})
	end
end

local function scroll_workspace(offset)
	local monitor = hl.get_active_monitor()
	if not monitor or not monitor.active_workspace then
		return
	end

	local index = workspace_scroll and workspace_scroll.index
	if not index then
		for current_index, id in ipairs(all_workspaces) do
			if id == monitor.active_workspace.id then
				index = current_index
				break
			end
		end
	end

	local target_index = index and index + offset
	local target = target_index and all_workspaces[target_index]
	if not target then
		return
	end

	local generation = (workspace_scroll and workspace_scroll.generation or 0) + 1
	workspace_scroll = { index = target_index, generation = generation }
	hl.dispatch(hl.dsp.focus({ workspace = target }))
end

local function toggle_aspect_ratio()
	aspect_ratio_enabled = not aspect_ratio_enabled
	hl.config({
		layout = {
			single_window_aspect_ratio = aspect_ratio_enabled and { 16, 9 } or { 0, 0 },
		},
	})
end

for _, monitor in ipairs(configured_monitors) do
	assign_workspaces(monitor.output, monitor.workspaces)

	-- Route each screensaver instance before it maps. Its title contains output
	-- name, allowing all instances to launch concurrently without focus changes.
	hl.window_rule({
		name = "tte-screensaver-" .. monitor.output,
		match = {
			class = "^tte-screensaver$",
			title = "^tte-screensaver-" .. monitor.output .. "$",
		},
		monitor = monitor.output,
	})

	hl.monitor({
		output = monitor.output,
		mode = monitor.mode,
		position = monitor.position,
		scale = monitor.scale,
	})
end

table.sort(all_workspaces)

-- =============================================================================
-- KEYBIND HELPERS
-- =============================================================================

local gaps_enabled = true
local DEFAULT_GAPS_IN, DEFAULT_GAPS_OUT = 4, 8

local function toggle_window_gaps()
	gaps_enabled = not gaps_enabled
	hl.config({
		general = {
			gaps_in = gaps_enabled and DEFAULT_GAPS_IN or 0,
			gaps_out = gaps_enabled and DEFAULT_GAPS_OUT or 0,
		},
	})
end

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

-- Toggles focused window's `opaque` prop, bypassing configured opacity until
-- toggled back.
local function toggle_window_opacity()
	local window = hl.get_active_window()
	if not window then
		return
	end

	hl.dispatch(hl.dsp.window.set_prop({
		window = "address:" .. window.address,
		prop = "opaque",
		value = "toggle",
	}))
end

local function open_terminal()
	hl.dispatch(hl.dsp.exec_cmd("launch-terminal-cwd"))
end

local function focus_next_workspace()
	scroll_workspace(1)
end

local function focus_previous_workspace()
	scroll_workspace(-1)
end

local function bind(keys, description, dispatcher, options)
	assert(description and description ~= "", "Keybind description is required for " .. keys)
	options = options or {}
	options.desc = description
	return hl.bind(keys, dispatcher, options)
end

local screenshot_command =
	'mkdir -p ~/Screenshots && file="$HOME/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png" && grim -g "$(slurp)" "$file" && wl-copy --type image/png < "$file"'

-- =============================================================================
-- KEYBINDS: SYSTEM
-- =============================================================================

bind("SUPER + L", "Lock session", hl.dsp.exec_cmd("qs ipc call lock activate"))
bind("XF86PowerOff", "Suspend system", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })
bind("switch:on:Lid Switch", "Suspend when lid closes", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

-- =============================================================================
-- KEYBINDS: APPS AND WINDOW ACTIONS
-- =============================================================================

bind("SUPER + S", "Toggle terminal workspace", hl.dsp.workspace.toggle_special("terminal"))
bind("SUPER + E", "Open file manager", hl.dsp.exec_cmd("nautilus"))
bind("SUPER + Return", "Open terminal", open_terminal)
bind("SUPER + W", "Close active window", hl.dsp.window.close())
bind("SUPER + J", "Toggle split direction", hl.dsp.layout("togglesplit"))
bind("SUPER + T", "Toggle floating window", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + F", "Toggle fullscreen window", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + Tab", "Focus previous workspace", hl.dsp.focus({ workspace = "previous" }))
bind("SUPER + mouse_down", "Focus next workspace", focus_next_workspace)
bind("SUPER + mouse_up", "Focus previous workspace", focus_previous_workspace)

-- =============================================================================
-- KEYBINDS: WINDOW FOCUS AND MOVEMENT
-- =============================================================================

bind("SUPER + left", "Focus window left", hl.dsp.focus({ direction = "left" }))
bind("SUPER + right", "Focus window right", hl.dsp.focus({ direction = "right" }))
bind("SUPER + up", "Focus window up", hl.dsp.focus({ direction = "up" }))
bind("SUPER + down", "Focus window down", hl.dsp.focus({ direction = "down" }))
bind("SUPER + SHIFT + left", "Move window left", hl.dsp.window.move({ direction = "left" }))
bind("SUPER + SHIFT + right", "Move window right", hl.dsp.window.move({ direction = "right" }))
bind("SUPER + SHIFT + up", "Move window up", hl.dsp.window.move({ direction = "up" }))
bind("SUPER + SHIFT + down", "Move window down", hl.dsp.window.move({ direction = "down" }))

-- =============================================================================
-- KEYBINDS: WORKSPACES
-- =============================================================================

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
-- bind("SUPER + SHIFT + S", "Move window to special workspace", hl.dsp.window.move({ workspace = "special:terminal" }))

-- =============================================================================
-- KEYBINDS: RESIZE, SCREENSHOTS, AND APPEARANCE
-- =============================================================================

bind(
	"SUPER + equal",
	"Increase window width",
	hl.dsp.window.resize({ x = 75, y = 0, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + minus",
	"Decrease window width",
	hl.dsp.window.resize({ x = -75, y = 0, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + SHIFT + minus",
	"Increase window height",
	hl.dsp.window.resize({ x = 0, y = 75, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + SHIFT + equal",
	"Decrease window height",
	hl.dsp.window.resize({ x = 0, y = -75, relative = true }),
	{ repeating = true }
)
bind("SUPER + mouse:272", "Drag window", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
bind(
	"SUPER + SHIFT + K",
	"Pick screen colour and copy hex code",
	hl.dsp.exec_cmd("hyprpicker --autocopy --format=hex --lowercase-hex")
)
bind("SUPER + SHIFT + S", "Capture screen region", hl.dsp.exec_cmd(screenshot_command))
bind("SUPER + M", "Toggle single-window max width", toggle_aspect_ratio)
bind("SUPER + backspace", "Toggle window opacity", toggle_window_opacity)
bind("SUPER + SHIFT + backspace", "Toggle window gaps", toggle_window_gaps)

-- =============================================================================
-- KEYBINDS: CLIPBOARD
-- =============================================================================

bind("SUPER + X", "Universal cut", send_shortcut_once("CTRL", "X"))
bind("SUPER + C", "Universal copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
bind("SUPER + V", "Universal paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

-- =============================================================================
-- KEYBINDS: AUDIO AND BRIGHTNESS
-- =============================================================================

bind(
	"XF86AudioRaiseVolume",
	"Raise audio volume",
	hl.dsp.exec_cmd("qs ipc call audio outputUp"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioLowerVolume",
	"Lower audio volume",
	hl.dsp.exec_cmd("qs ipc call audio outputDown"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioMute",
	"Toggle audio mute",
	hl.dsp.exec_cmd("qs ipc call audio toggleOutputMute"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioMicMute",
	"Toggle microphone mute",
	hl.dsp.exec_cmd("qs ipc call audio toggleInputMute"),
	{ locked = true, repeating = true }
)
bind(
	"XF86MonBrightnessUp",
	"Raise display brightness",
	hl.dsp.exec_cmd("qs ipc call display brightnessUp"),
	{ locked = true, repeating = true }
)
bind(
	"XF86MonBrightnessDown",
	"Lower display brightness",
	hl.dsp.exec_cmd("qs ipc call display brightnessDown"),
	{ locked = true, repeating = true }
)

-- =============================================================================
-- KEYBINDS: DICTATION AND UI
-- =============================================================================

bind("SUPER + SHIFT + V", "Toggle dictation", hl.dsp.exec_cmd("voxtype record toggle"))
bind("F9", "Start dictation", hl.dsp.exec_cmd("voxtype record start"))
bind("F9", "Stop dictation", hl.dsp.exec_cmd("voxtype record stop"), { release = true })

-- Dispatch directly to Quickshell's registered global shortcut. This avoids
-- starting the ~50 ms `qs` Qt IPC client on every invocation.
bind("SUPER + space", "Toggle app launcher", hl.dsp.global("quickshell:launcher"))
bind("SUPER + CTRL + P", "Toggle power panel", hl.dsp.exec_cmd("qs ipc call panels toggle power"))
bind("SUPER + CTRL + C", "Toggle calendar panel", hl.dsp.exec_cmd("qs ipc call panels toggle calendar"))
bind("SUPER + CTRL + L", "Toggle night-light panel", hl.dsp.exec_cmd("qs ipc call panels toggle nightlight"))
bind("SUPER + CTRL + T", "Toggle timer panel", hl.dsp.exec_cmd("qs ipc call panels toggle timer"))
bind("SUPER + CTRL + R", "Toggle system-tray panel", hl.dsp.exec_cmd("qs ipc call panels toggle tray"))
bind("SUPER + CTRL + V", "Toggle volume panel", hl.dsp.exec_cmd("qs ipc call panels toggle volume"))
bind("SUPER + CTRL + D", "Toggle Bluetooth panel", hl.dsp.exec_cmd("qs ipc call panels toggle bluetooth"))
bind("SUPER + CTRL + M", "Toggle display panel", hl.dsp.exec_cmd("qs ipc call panels toggle display"))
bind("SUPER + CTRL + N", "Toggle network panel", hl.dsp.exec_cmd("qs ipc call panels toggle network"))
bind("SUPER + CTRL + B", "Toggle battery panel", hl.dsp.exec_cmd("qs ipc call panels toggle battery"))
bind("SUPER + CTRL + S", "Toggle stay-awake mode", hl.dsp.exec_cmd("qs ipc call stayawake toggle"))
bind("SUPER + CTRL + SHIFT + D", "Toggle do-not-disturb mode", hl.dsp.exec_cmd("qs ipc call dnd toggle"))
bind("SUPER + SHIFT + space", "Toggle status bar", hl.dsp.exec_cmd("qs ipc call bar toggle"))
