-- =============================================================================
-- general
-- =============================================================================

hl.config({
	input = {
		sensitivity = 0.4,
		-- No pointer acceleration for mice; the touchpad keeps it below.
		accel_profile = "flat",
		repeat_rate = 30,
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
		layout = "dwindle",
	},
	decoration = {
		rounding = 0,
		active_opacity = 0.99,
		inactive_opacity = 0.96,
		blur = { enabled = true, xray = false, special = true, passes = 2, size = 3 },
		shadow = { enabled = false },
	},
	animations = { enabled = true, workspace_wraparound = true },
	layout = { single_window_aspect_ratio = { 16, 9 } },

	dwindle = {
		preserve_split = false,
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		focus_on_activate = true,
	},
})

hl.device({ name = "msft0001:01-06cb:cd5f-touchpad", accel_profile = "adaptive", sensitivity = 0.2 })

-- =============================================================================
-- animations
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
	{ enabled = false, leaf = "workspaces", speed = 1, bezier = "fast" },
	{ enabled = true, leaf = "windows", speed = 100, spring = "spring" },
	{ enabled = true, leaf = "windowsOut", speed = 100, spring = "spring" },
	{ enabled = true, leaf = "specialWorkspace", speed = 1.5, bezier = "fast", style = "slidevert" },
	{ enabled = true, leaf = "fade", speed = 4, bezier = "fast" },
}

for _, animation in ipairs(animations) do
	hl.animation(animation)
end

-- =============================================================================
-- layers
-- =============================================================================

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
-- window rules
-- =============================================================================

-- Floating application windows.
local floating_windows = {
	{ class = "xdg-desktop-portal-gtk", center = true },
	{ title = "termfilechooser", center = true },
	{ class = "1password", center = true },
	{ class = "^com.gabm.satty$", center = true }, -- screenshot annotator (StartupWMClass)
	{ name = "gnome-calculator", class = "^org.gnome.Calculator$", size = { 360, 616 } },
	{ name = "floating-terminal", class = "^floating-terminal$" },
}

for _, window in ipairs(floating_windows) do
	hl.window_rule({
		name = window.name,
		match = window.title and { title = window.title } or { class = window.class },
		float = true,
		center = window.center,
		size = window.size or { 1300, 800 },
	})
end

-- Apps (Electron/GTK mostly) request maximize on launch and take the whole
-- screen; tiling already sizes them.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
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

-- Keep normal translucent windows sharp; the special workspace backdrop uses
-- decoration.blur.special independently of per-window blur.
hl.window_rule({
	name = "disable-regular-window-blur",
	match = { class = ".*" },
	no_blur = true,
})

-- =============================================================================
-- monitors & workspaces
-- =============================================================================

local configured_monitors = {
	{
		output = "eDP-1",
		mode = "1920x1080@60",
		position = "0x0",
		scale = 1,
		workspaces = { 7, 8, 9 },
		-- Used instead when this is the only connected output.
		laptop_only_workspaces = { 1, 2, 3 },
	},
	{
		output = "HDMI-A-1",
		mode = "3440x1440@59.96Hz",
		position = "1920x0",
		scale = 1,
		workspaces = { 1, 2, 3, 4, 5, 6},
	},
}

local aspect_ratio_enabled = true

-- Never leave the compositor without an output: with the lid closed on the
-- laptop alone, the system is suspending anyway, and an output-less compositor
-- orphans workspaces and strands layer-shell surfaces on stale screens.
local function external_monitor_connected()
	for _, monitor in ipairs(hl.get_monitors()) do
		if monitor.name ~= "eDP-1" then
			return true
		end
	end
	return false
end

-- Workspaces with the same name share one rule, so switching layouts redefines each rule's output.
local function workspace_layout()
	local docked = external_monitor_connected()
	local layout = {}

	for _, monitor in ipairs(configured_monitors) do
		local own = docked and monitor.workspaces or monitor.laptop_only_workspaces
		for _, workspace in ipairs(own or {}) do
			layout[workspace] = { output = monitor.output, persistent = true }
		end
	end

	-- Laptop alone: every other workspace opens on it on demand.
	if not docked then
		for _, monitor in ipairs(configured_monitors) do
			for _, workspace in ipairs(monitor.workspaces) do
				layout[workspace] = layout[workspace] or { output = "eDP-1", persistent = false }
			end
		end
	end

	return layout
end

local function apply_workspace_layout()
	local layout = workspace_layout()

	for workspace, entry in pairs(layout) do
		hl.workspace_rule({
			workspace = tostring(workspace),
			monitor = entry.output,
			default = entry.persistent,
			persistent = entry.persistent,
		})
	end

	-- Rules only place new workspaces, so move existing ones to their output.
	for _, workspace in ipairs(hl.get_workspaces()) do
		local entry = layout[workspace.id]
		if entry and workspace.monitor and workspace.monitor.name ~= entry.output and hl.get_monitor(entry.output) then
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(workspace.id), monitor = entry.output }))
		end
	end

	-- Show each output's first own workspace if it is displaying a foreign one.
	for _, monitor in ipairs(hl.get_monitors()) do
		local current = monitor.active_workspace
		local entry = current and layout[current.id]
		if not entry or entry.output ~= monitor.name then
			for _, configured in ipairs(configured_monitors) do
				if configured.output == monitor.name then
					local own = external_monitor_connected() and configured.workspaces or configured.laptop_only_workspaces
					if own and own[1] then
						hl.dispatch(hl.dsp.focus({ workspace = own[1] }))
					end
				end
			end
		end
	end
end

local function toggle_aspect_ratio()
	aspect_ratio_enabled = not aspect_ratio_enabled
	hl.config({
		layout = {
			single_window_aspect_ratio = aspect_ratio_enabled and { 16, 9 } or { 0, 0 },
		},
	})
end

-- At boot no outputs exist yet, so this starts with the laptop-only layout.
apply_workspace_layout()

for _, monitor in ipairs(configured_monitors) do
	hl.monitor({
		output = monitor.output,
		mode = monitor.mode,
		position = monitor.position,
		scale = monitor.scale,
	})
end

-- Wait for the output to settle before moving workspaces onto it.
local function apply_workspace_layout_soon()
	hl.timer(apply_workspace_layout, { timeout = 200, type = "oneshot" })
end

hl.on("hyprland.start", apply_workspace_layout_soon)
hl.on("monitor.added", apply_workspace_layout_soon)
hl.on("monitor.removed", apply_workspace_layout_soon)

-- =============================================================================
-- keybind functions / helpers
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



local function open_terminal()
	hl.dispatch(hl.dsp.exec_cmd("launch-terminal-cwd"))
end

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

local function toggle_centered_floating()
	local window = hl.get_active_window()
	if not window then
		return
	end

	local selector = "address:" .. window.address
	if window.floating then
		hl.dispatch(hl.dsp.window.float({ action = "unset", window = selector }))
		return
	end

	hl.dispatch(hl.dsp.window.float({ action = "set", window = selector }))
	hl.dispatch(hl.dsp.window.resize({ x = 1300, y = 800, window = selector }))
	hl.dispatch(hl.dsp.window.center({ window = selector }))
end

local function find_workspace(id)
	for _, workspace in ipairs(hl.get_workspaces()) do
		if workspace.id == id then
			return workspace
		end
	end
end

local function change_workspace_id(from, to)
	hl.dispatch(hl.dsp.workspace.change_id({ workspace = tostring(from), id = to }))
end

-- Renumber whole workspaces (target -> temp, current -> target, temp -> current) so
-- their windows and layouts move intact; focus stays with the renumbered workspace.
local function swap_workspace_with(target)
	return function()
		local current = hl.get_active_workspace()
		if not current or current.id == target then
			return
		end

		local source = current.id
		local source_monitor = current.monitor and current.monitor.name
		local target_workspace = find_workspace(target)
		local target_monitor = target_workspace and target_workspace.monitor and target_workspace.monitor.name
		local temp = 10000 + target

		if target_workspace then
			change_workspace_id(target, temp)
		end
		change_workspace_id(source, target)
		if target_workspace then
			change_workspace_id(temp, source)
		end

		-- Each number keeps its screen, so the contents trade screens.
		if target_monitor and source_monitor and target_monitor ~= source_monitor then
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(target), monitor = target_monitor }))
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(source), monitor = source_monitor }))
			hl.dispatch(hl.dsp.focus({ workspace = target }))
		end
	end
end

local function open_floating_terminal()
	hl.dispatch(hl.dsp.exec_cmd("launch-terminal-cwd --class floating-terminal"))
end

local function bind(keys, description, dispatcher, options)
	assert(description and description ~= "", "Keybind description is required for " .. keys)
	options = options or {}
	options.desc = description
	return hl.bind(keys, dispatcher, options)
end

-- =============================================================================
-- gestures
-- =============================================================================

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- =============================================================================
-- keysbinds - system
-- =============================================================================

bind("SUPER + L", "Lock the current session", hl.dsp.exec_cmd("qs ipc call lock activate"))
local function enable_laptop_display()
	hl.monitor({
		output = "eDP-1",
		disabled = false,
		mode = "1920x1080@60",
		position = "0x0",
		scale = 1,
	})
end

bind("switch:on:Lid Switch", "Disable the laptop display when the lid closes (external monitor only)", function()
	if external_monitor_connected() then
		hl.monitor({ output = "eDP-1", disabled = true })
	end
end, { locked = true })
bind("switch:off:Lid Switch", "Enable the laptop display when the lid opens", function()
	enable_laptop_display()
	-- Rejoin the output before enabling DPMS, then re-apply once the GPU has
	-- settled after resume in case the first modeset raced the wake-up.
	hl.timer(function()
		hl.dispatch(hl.dsp.dpms({ action = "enable", monitor = "eDP-1" }))
	end, { timeout = 250, type = "oneshot" })
	hl.timer(function()
		enable_laptop_display()
	end, { timeout = 1500, type = "oneshot" })
end, { locked = true })

-- =============================================================================
-- keybinds - window management
-- =============================================================================

bind("SUPER + S", "Toggle the terminal workspace", hl.dsp.workspace.toggle_special("terminal"))
bind("SUPER + CTRL + SHIFT + S", "Move focused window to terminal workspace", hl.dsp.window.move({ workspace = "special:terminal" }))
bind("SUPER + E", "Open Yazi file manager", hl.dsp.exec_cmd("launch-terminal-cwd yazi"))
bind("SUPER + Return", "Open terminal in current directory", open_terminal)
bind("SUPER + CTRL + Return", "Open a floating terminal", open_floating_terminal)
bind("SUPER + W", "Close the focused window", hl.dsp.window.close())
bind("SUPER + J", "Toggle the next split direction", hl.dsp.layout("togglesplit"))
bind("SUPER + T", "Toggle a centered floating window", toggle_centered_floating)
bind("SUPER + F", "Toggle fullscreen for focused window", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind("SUPER + Tab", "Switch to the previously used workspace", hl.dsp.focus({ workspace = "previous" }))

-- =============================================================================
-- keybinds - window focus and movement
-- =============================================================================

bind("SUPER + left", "Focus the window to the left", hl.dsp.focus({ direction = "left" }))
bind("SUPER + right", "Focus the window to the right", hl.dsp.focus({ direction = "right" }))
bind("SUPER + up", "Focus the window above", hl.dsp.focus({ direction = "up" }))
bind("SUPER + down", "Focus the window below", hl.dsp.focus({ direction = "down" }))
bind("SUPER + SHIFT + left", "Move the focused window left", hl.dsp.window.move({ direction = "left" }))
bind("SUPER + SHIFT + right", "Move the focused window right", hl.dsp.window.move({ direction = "right" }))
bind("SUPER + SHIFT + up", "Move the focused window up", hl.dsp.window.move({ direction = "up" }))
bind("SUPER + SHIFT + down", "Move the focused window down", hl.dsp.window.move({ direction = "down" }))

-- =============================================================================
-- keybinds - workspaces
-- =============================================================================

bind("SUPER + 1", "Switch to workspace 1", hl.dsp.focus({ workspace = 1 }))
bind("SUPER + 2", "Switch to workspace 2", hl.dsp.focus({ workspace = 2 }))
bind("SUPER + 3", "Switch to workspace 3", hl.dsp.focus({ workspace = 3 }))
bind("SUPER + 4", "Switch to workspace 4", hl.dsp.focus({ workspace = 4 }))
bind("SUPER + 5", "Switch to workspace 5", hl.dsp.focus({ workspace = 5 }))
bind("SUPER + 6", "Switch to workspace 6", hl.dsp.focus({ workspace = 6 }))
bind("SUPER + 7", "Switch to workspace 7", hl.dsp.focus({ workspace = 7 }))
bind("SUPER + 8", "Switch to workspace 8", hl.dsp.focus({ workspace = 8 }))
bind("SUPER + 9", "Switch to workspace 9", hl.dsp.focus({ workspace = 9 }))
bind("SUPER + 0", "Switch to workspace 0", hl.dsp.focus({ workspace = 10 }))

bind("SUPER + SHIFT + 1", "Move focused window to workspace 1", hl.dsp.window.move({ workspace = 1 }))
bind("SUPER + SHIFT + 2", "Move focused window to workspace 2", hl.dsp.window.move({ workspace = 2 }))
bind("SUPER + SHIFT + 3", "Move focused window to workspace 3", hl.dsp.window.move({ workspace = 3 }))
bind("SUPER + SHIFT + 4", "Move focused window to workspace 4", hl.dsp.window.move({ workspace = 4 }))
bind("SUPER + SHIFT + 5", "Move focused window to workspace 5", hl.dsp.window.move({ workspace = 5 }))
bind("SUPER + SHIFT + 6", "Move focused window to workspace 6", hl.dsp.window.move({ workspace = 6 }))
bind("SUPER + SHIFT + 7", "Move focused window to workspace 7", hl.dsp.window.move({ workspace = 7 }))
bind("SUPER + SHIFT + 8", "Move focused window to workspace 8", hl.dsp.window.move({ workspace = 8 }))
bind("SUPER + SHIFT + 9", "Move focused window to workspace 9", hl.dsp.window.move({ workspace = 9 }))
bind("SUPER + SHIFT + 0", "Move focused window to workspace 0", hl.dsp.window.move({ workspace = 10 }))

bind("SUPER + CTRL + 1", "Swap the focused workspace with workspace 1", swap_workspace_with(1))
bind("SUPER + CTRL + 2", "Swap the focused workspace with workspace 2", swap_workspace_with(2))
bind("SUPER + CTRL + 3", "Swap the focused workspace with workspace 3", swap_workspace_with(3))
bind("SUPER + CTRL + 4", "Swap the focused workspace with workspace 4", swap_workspace_with(4))
bind("SUPER + CTRL + 5", "Swap the focused workspace with workspace 5", swap_workspace_with(5))
bind("SUPER + CTRL + 6", "Swap the focused workspace with workspace 6", swap_workspace_with(6))
bind("SUPER + CTRL + 7", "Swap the focused workspace with workspace 7", swap_workspace_with(7))
bind("SUPER + CTRL + 8", "Swap the focused workspace with workspace 8", swap_workspace_with(8))
bind("SUPER + CTRL + 9", "Swap the focused workspace with workspace 9", swap_workspace_with(9))
bind("SUPER + CTRL + 0", "Swap the focused workspace with workspace 0", swap_workspace_with(10))

-- =============================================================================
-- keybinds - window resizing and dragging
-- =============================================================================

bind("SUPER + equal", "Increase the focused window width", hl.dsp.window.resize({ x = 75, y = 0, relative = true }), { repeating = true })
bind("SUPER + minus", "Decrease the focused window width", hl.dsp.window.resize({ x = -75, y = 0, relative = true }), { repeating = true })
bind("SUPER + SHIFT + minus", "Increase the focused window height", hl.dsp.window.resize({ x = 0, y = 75, relative = true }), { repeating = true })
bind("SUPER + SHIFT + equal", "Decrease the focused window height", hl.dsp.window.resize({ x = 0, y = -75, relative = true }), { repeating = true })
bind("SUPER + mouse:272", "Drag the focused window", hl.dsp.window.drag(), { mouse = true })
bind("SUPER + mouse:273", "Resize the focused window", hl.dsp.window.resize(), { mouse = true })
bind("SUPER + SHIFT + K", "Pick a colour and copy its hex value", hl.dsp.exec_cmd("hyprpicker --autocopy --format=hex --lowercase-hex"))
bind("SUPER + SHIFT + S", "Capture a selected screen region", hl.dsp.exec_cmd("screenshot"))
bind("SUPER + M", "Toggle the single-window width limit", toggle_aspect_ratio)
bind("SUPER + backspace", "Toggle opacity override for focused window", toggle_window_opacity)
bind("SUPER + SHIFT + backspace", "Toggle spacing between windows", toggle_window_gaps)

-- =============================================================================
-- keybinds - clipboard
-- =============================================================================

bind("SUPER + X", "Cut the selection to the clipboard", send_shortcut_once("CTRL", "X"))
bind("SUPER + C", "Copy the selection to the clipboard", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"))
bind("SUPER + V", "Paste content from the clipboard", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))

-- =============================================================================
-- keybinds - audio and brightness
-- =============================================================================

bind("XF86AudioRaiseVolume", "Increase the output volume", hl.dsp.exec_cmd("qs ipc call audio outputUp"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume", "Decrease the output volume", hl.dsp.exec_cmd("qs ipc call audio outputDown"), { locked = true, repeating = true })
bind("XF86AudioMute", "Toggle output audio mute", hl.dsp.exec_cmd("qs ipc call audio toggleOutputMute"), { locked = true, repeating = true })
bind("XF86AudioMicMute", "Toggle microphone mute", hl.dsp.exec_cmd("qs ipc call audio toggleInputMute"), { locked = true, repeating = true })
bind("XF86MonBrightnessUp", "Increase display brightness", hl.dsp.exec_cmd("qs ipc call monitor brightnessUp"), { locked = true })
bind("XF86MonBrightnessDown", "Decrease display brightness", hl.dsp.exec_cmd("qs ipc call monitor brightnessDown"), { locked = true })

-- =============================================================================
-- keybinds - voice dictation
-- =============================================================================

bind("SUPER + SHIFT + V", "Toggle voice dictation recording", hl.dsp.exec_cmd("voxtype record toggle"))
bind("F9", "Start voice dictation recording", hl.dsp.exec_cmd("voxtype record start"))
bind("F9", "Stop voice dictation recording", hl.dsp.exec_cmd("voxtype record stop"), { release = true })

-- =============================================================================
-- keybinds - quickshell and panels
-- =============================================================================

bind("SUPER + space", "Open or close the application launcher", hl.dsp.global("quickshell:launcher"))
bind("SUPER + grave", "Open or close the application launcher", hl.dsp.global("quickshell:launcher"))
bind("SUPER + CTRL + K", "Browse configured keyboard shortcuts", hl.dsp.global("quickshell:keybinds"))
bind("SUPER + CTRL + C", "Open or close the clock panel", hl.dsp.exec_cmd("qs ipc call panels toggle clock"))
bind("SUPER + CTRL + L", "Open or close the night-light panel", hl.dsp.exec_cmd("qs ipc call panels toggle nightlight"))
bind("SUPER + CTRL + T", "Open or close the timer panel", hl.dsp.exec_cmd("qs ipc call panels toggle timer"))
bind("SUPER + CTRL + R", "Open or close the system tray", hl.dsp.exec_cmd("qs ipc call panels toggle tray"))
bind("SUPER + CTRL + A", "Open or close the audio panel", hl.dsp.exec_cmd("qs ipc call panels toggle audio"))
bind("SUPER + CTRL + B", "Open or close the Bluetooth panel", hl.dsp.exec_cmd("qs ipc call panels toggle bluetooth"))
bind("SUPER + CTRL + M", "Open or close the monitor panel", hl.dsp.exec_cmd("qs ipc call panels toggle monitor"))
bind("SUPER + CTRL + N", "Open or close the network panel", hl.dsp.exec_cmd("qs ipc call panels toggle network"))
bind("SUPER + CTRL + P", "Open or close the battery panel", hl.dsp.exec_cmd("qs ipc call panels toggle battery"))
bind("SUPER + CTRL + S", "Toggle automatic sleep inhibition", hl.dsp.exec_cmd("qs ipc call stayawake toggle"))
bind("SUPER + CTRL + SHIFT + L", "Toggle night light", hl.dsp.exec_cmd("qs ipc call nightlight toggle"))
bind("SUPER + CTRL + D", "Toggle notification do-not-disturb", hl.dsp.exec_cmd("qs ipc call dnd toggle"))
bind("SUPER + SHIFT + space", "Show or hide the status bar", hl.dsp.exec_cmd("qs ipc call bar toggle"))
