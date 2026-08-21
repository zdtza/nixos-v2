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
		rounding = 0,
		active_opacity = 0.98,
		inactive_opacity = 0.96,
		blur = { enabled = true, special = true, passes = 2, size = 3 },
		shadow = {
			enabled = true,
			range = 20,
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
