-- Stylix generates this bridge from the selected theme.
local stylix = dofile(os.getenv("HOME") .. "/.config/hypr/stylix.lua")
_G.ACTIVE_BORDER_COLOR = stylix.active_border_color
_G.INACTIVE_BORDER_COLOR = stylix.inactive_border_color

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
			scroll_factor = 0.8,
		},
	},
	binds = { scroll_event_delay = 0 },
	cursor = { no_hardware_cursors = true },
	general = {
		gaps_in = 3,
		gaps_out = 6,
		border_size = 0,
		col = {
			active_border = ACTIVE_BORDER_COLOR,
			inactive_border = INACTIVE_BORDER_COLOR,
		},
		layout = "dwindle",
	},
	decoration = {
		rounding = 0,
		active_opacity = 0.99,
		inactive_opacity = 0.96,
		blur = { enabled = false, xray = false, special = true, passes = 2, size = 3 },
		shadow = { enabled = false },
	},
	animations = { enabled = true },
	layout = { single_window_aspect_ratio = { 16, 9 } },

	dwindle = {
		preserve_split = true,
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
	{ enabled = false, leaf = "workspaces", speed = 1.5, bezier = "fast" },
	{ enabled = true, leaf = "windows", speed = 100, spring = "spring" },
	{ enabled = true, leaf = "windowsOut", speed = 100, spring = "spring" },
	{ enabled = true, leaf = "specialWorkspace", speed = 1.5, bezier = "fast", style = "slidevert" },
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
local quickshell_layers = {
	"quickshell:background",
	"quickshell:bar",
	"quickshell:launcher",
	"quickshell:keybinds",
	"quickshell:image-picker",
	"quickshell:center-panel",
	"quickshell:panel-drawer",
}

for _, namespace in ipairs(quickshell_layers) do
	hl.layer_rule({
		match = { namespace = "^" .. namespace .. "$" },
		no_anim = true,
	})
end

-- =============================================================================
-- WINDOW RULES
-- =============================================================================

-- Apps (Electron/GTK mostly) request maximize on launch and take the whole
-- screen; tiling already sizes them.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Generic float/center rules for picker-style windows.
local picker_windows = {
	{ class = "xdg-desktop-portal-gtk" },
	{ title = "termfilechooser" },
	{ class = "1password" },
	{ class = "^com.gabm.satty$" }, -- screenshot annotator (StartupWMClass)
}

for _, window in ipairs(picker_windows) do
	hl.window_rule({
		match = window.title and { title = window.title } or { class = window.class },
		float = true,
		center = true,
		size = window.size or { 1300, 800 },
	})
end

-- FreeRDP's dynamic-resolution channel can miss the final configure event when
-- its tiled window is resized through the opening animation. Map it directly
-- at its settled size so the initial desktop resolution is applied immediately.
hl.window_rule({
	name = "windows-rdp",
	match = { class = "^windows$" },
	no_anim = true,
})

hl.window_rule({
	name = "gnome-calculator",
	match = { class = "^org.gnome.Calculator$" },
	float = true,
	size = { 360, 616 },
})

-- Matched by open_floating_terminal's `--class` below, kept floating instead
-- of tiling in like a normal launch-terminal-cwd window.
hl.window_rule({
	name = "floating-terminal",
	match = { class = "^floating-terminal$" },
	float = true,
	center = true,
	size = { 900, 600 },
})

-- Hide Teams' screen-sharing indicator without stealing focus.
hl.window_rule({
	name = "teams-screen-share-indicator",
	match = {
		class = "^teams-for-linux$",
		title = "^Teams for Linux - Screen is being shared$",
	},
	workspace = "special:hidden silent", -- Route silently to background scratchpad
	no_focus = true, -- Do not steal focus on launch
})

hl.window_rule({
	match = { float = true },
	-- Override global opacity: active, inactive, fullscreen.
	opacity = "0.99 override 0.98 override 1.0 override",
})

-- =============================================================================
-- MONITORS AND WORKSPACES
-- =============================================================================

-- Built-in display and external ultrawide, each with assigned workspaces.
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

local function open_floating_terminal()
	hl.dispatch(hl.dsp.exec_cmd("launch-terminal-cwd --class floating-terminal"))
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

-- Capture, copy and notify; clicking opens satty (home/screenshot.nix).
local screenshot_command = "screenshot"

-- =============================================================================
-- GESTURES
-- =============================================================================

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- =============================================================================
-- KEYBINDS: SYSTEM
-- =============================================================================

bind("SUPER + L", "Lock screen", hl.dsp.exec_cmd("qs ipc call lock activate"))
bind("switch:on:Lid Switch", "Suspend then hibernate", hl.dsp.exec_cmd("systemctl suspend-then-hibernate"), { locked = true })

-- =============================================================================
-- KEYBINDS: APPS AND WINDOW ACTIONS
-- =============================================================================

bind("SUPER + S", "Terminal workspace", hl.dsp.workspace.toggle_special("terminal"))
bind("SUPER + CTRL + SHIFT + S", "Move window to terminal workspace", hl.dsp.window.move({ workspace = "special:terminal" }))
-- This path does not pass through an interactive shell, so inject fzf's
-- stable options file explicitly rather than relying on Fish session vars.
bind("SUPER + E", "File manager", hl.dsp.exec_cmd("env -u FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE=$HOME/.config/fzf/options launch-terminal-cwd yazi"))
bind("SUPER + Return", "Terminal", open_terminal)
bind("SUPER + CTRL + Return", "Floating terminal", open_floating_terminal)
bind("SUPER + W", "Close window", hl.dsp.window.close())
bind("SUPER + J", "Split direction", hl.dsp.layout("togglesplit"))
bind("SUPER + T", "Float window", hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + F", "Fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + Tab", "Previous workspace", hl.dsp.focus({ workspace = "previous" }))
bind("SUPER + mouse_down", "Next workspace", focus_next_workspace)
bind("SUPER + mouse_up", "Previous workspace", focus_previous_workspace)

-- =============================================================================
-- KEYBINDS: WINDOW FOCUS AND MOVEMENT
-- =============================================================================

bind("SUPER + left", "Focus left", hl.dsp.focus({ direction = "left" }))
bind("SUPER + right", "Focus right", hl.dsp.focus({ direction = "right" }))
bind("SUPER + up", "Focus up", hl.dsp.focus({ direction = "up" }))
bind("SUPER + down", "Focus down", hl.dsp.focus({ direction = "down" }))
bind("SUPER + SHIFT + left", "Move left", hl.dsp.window.move({ direction = "left" }))
bind("SUPER + SHIFT + right", "Move right", hl.dsp.window.move({ direction = "right" }))
bind("SUPER + SHIFT + up", "Move up", hl.dsp.window.move({ direction = "up" }))
bind("SUPER + SHIFT + down", "Move down", hl.dsp.window.move({ direction = "down" }))

-- =============================================================================
-- KEYBINDS: WORKSPACES
-- =============================================================================

bind("SUPER + 1", "Workspace 1", hl.dsp.focus({ workspace = 1 }))
bind("SUPER + 2", "Workspace 2", hl.dsp.focus({ workspace = 2 }))
bind("SUPER + 3", "Workspace 3", hl.dsp.focus({ workspace = 3 }))
bind("SUPER + 4", "Workspace 4", hl.dsp.focus({ workspace = 4 }))
bind("SUPER + 5", "Workspace 5", hl.dsp.focus({ workspace = 5 }))
bind("SUPER + 6", "Workspace 6", hl.dsp.focus({ workspace = 6 }))
bind("SUPER + 7", "Workspace 7", hl.dsp.focus({ workspace = 7 }))
bind("SUPER + 8", "Workspace 8", hl.dsp.focus({ workspace = 8 }))
bind("SUPER + 9", "Workspace 9", hl.dsp.focus({ workspace = 9 }))

bind("SUPER + SHIFT + 1", "Move to workspace 1", hl.dsp.window.move({ workspace = 1 }))
bind("SUPER + SHIFT + 2", "Move to workspace 2", hl.dsp.window.move({ workspace = 2 }))
bind("SUPER + SHIFT + 3", "Move to workspace 3", hl.dsp.window.move({ workspace = 3 }))
bind("SUPER + SHIFT + 4", "Move to workspace 4", hl.dsp.window.move({ workspace = 4 }))
bind("SUPER + SHIFT + 5", "Move to workspace 5", hl.dsp.window.move({ workspace = 5 }))
bind("SUPER + SHIFT + 6", "Move to workspace 6", hl.dsp.window.move({ workspace = 6 }))
bind("SUPER + SHIFT + 7", "Move to workspace 7", hl.dsp.window.move({ workspace = 7 }))
bind("SUPER + SHIFT + 8", "Move to workspace 8", hl.dsp.window.move({ workspace = 8 }))
bind("SUPER + SHIFT + 9", "Move to workspace 9", hl.dsp.window.move({ workspace = 9 }))

-- =============================================================================
-- KEYBINDS: RESIZE, SCREENSHOTS, AND APPEARANCE
-- =============================================================================

bind(
	"SUPER + equal",
	"Wider window",
	hl.dsp.window.resize({ x = 75, y = 0, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + minus",
	"Narrower window",
	hl.dsp.window.resize({ x = -75, y = 0, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + SHIFT + minus",
	"Taller window",
	hl.dsp.window.resize({ x = 0, y = 75, relative = true }),
	{ repeating = true }
)
bind(
	"SUPER + SHIFT + equal",
	"Shorter window",
	hl.dsp.window.resize({ x = 0, y = -75, relative = true }),
	{ repeating = true }
)
bind("SUPER + mouse:272", "Drag window", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
bind(
	"SUPER + SHIFT + K",
	"Colour picker",
	hl.dsp.exec_cmd("hyprpicker --autocopy --format=hex --lowercase-hex")
)
bind("SUPER + SHIFT + S", "Screenshot region", hl.dsp.exec_cmd(screenshot_command))
bind("SUPER + M", "Max width", toggle_aspect_ratio)
bind("SUPER + backspace", "Window opacity", toggle_window_opacity)
bind("SUPER + SHIFT + backspace", "Window gaps", toggle_window_gaps)

-- =============================================================================
-- KEYBINDS: CLIPBOARD
-- =============================================================================

bind("SUPER + X", "Cut", send_shortcut_once("CTRL", "X"))
bind("SUPER + C", "Copy", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
bind("SUPER + V", "Paste", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

-- =============================================================================
-- KEYBINDS: AUDIO AND BRIGHTNESS
-- =============================================================================

bind(
	"XF86AudioRaiseVolume",
	"Volume up",
	hl.dsp.exec_cmd("qs ipc call audio outputUp"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioLowerVolume",
	"Volume down",
	hl.dsp.exec_cmd("qs ipc call audio outputDown"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioMute",
	"Mute audio",
	hl.dsp.exec_cmd("qs ipc call audio toggleOutputMute"),
	{ locked = true, repeating = true }
)
bind(
	"XF86AudioMicMute",
	"Mute mic",
	hl.dsp.exec_cmd("qs ipc call audio toggleInputMute"),
	{ locked = true, repeating = true }
)
-- No `repeating` flag on these two: the brightness keys are firmware taps
-- (press plus a release ~30ms later, auto-repeated by the EC), so the key is
-- never held as far as the compositor is concerned and bind repeat never
-- fires. One step per tap, accelerated shell-side in DisplayService.
bind(
	"XF86MonBrightnessUp",
	"Brightness up",
	hl.dsp.exec_cmd("qs ipc call display brightnessUp"),
	{ locked = true }
)
bind(
	"XF86MonBrightnessDown",
	"Brightness down",
	hl.dsp.exec_cmd("qs ipc call display brightnessDown"),
	{ locked = true }
)

-- =============================================================================
-- KEYBINDS: DICTATION AND UI
-- =============================================================================

bind("SUPER + SHIFT + V", "Toggle Dictation", hl.dsp.exec_cmd("voxtype record toggle"))
bind("F9", "Start dictation", hl.dsp.exec_cmd("voxtype record start"))
bind("F9", "Stop dictation", hl.dsp.exec_cmd("voxtype record stop"), { release = true })

-- Dispatch directly to Quickshell's registered global shortcut. This avoids
-- starting the ~50 ms `qs` Qt IPC client on every invocation.
bind("SUPER + space", "App launcher", hl.dsp.global("quickshell:launcher"))
bind("SUPER + CTRL + K", "Keybinds", hl.dsp.global("quickshell:keybinds"))
bind("SUPER + CTRL + W", "Wallpaper picker", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
bind("SUPER + CTRL + A", "Theme picker", hl.dsp.exec_cmd("qs ipc call theme toggle"))
bind("SUPER + CTRL + C", "Clock", hl.dsp.exec_cmd("qs ipc call panels toggle clock"))
bind("SUPER + CTRL + L", "Night light", hl.dsp.exec_cmd("qs ipc call panels toggle nightlight"))
bind("SUPER + CTRL + T", "Timer", hl.dsp.exec_cmd("qs ipc call panels toggle timer"))
bind("SUPER + CTRL + R", "System tray", hl.dsp.exec_cmd("qs ipc call panels toggle tray"))
bind("SUPER + CTRL + V", "Volume", hl.dsp.exec_cmd("qs ipc call panels toggle volume"))
bind("SUPER + CTRL + B", "Bluetooth", hl.dsp.exec_cmd("qs ipc call panels toggle bluetooth"))
bind("SUPER + CTRL + D", "Display", hl.dsp.exec_cmd("qs ipc call panels toggle display"))
bind("SUPER + CTRL + N", "Network", hl.dsp.exec_cmd("qs ipc call panels toggle network"))
bind("SUPER + CTRL + P", "Battery", hl.dsp.exec_cmd("qs ipc call panels toggle battery"))
bind("SUPER + CTRL + S", "Stay awake", hl.dsp.exec_cmd("qs ipc call stayawake toggle"))
bind("SUPER + CTRL + SHIFT + D", "Do not disturb", hl.dsp.exec_cmd("qs ipc call dnd toggle"))
bind("SUPER + SHIFT + space", "Status bar", hl.dsp.exec_cmd("qs ipc call bar toggle"))
