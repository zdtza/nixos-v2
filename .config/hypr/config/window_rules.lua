-- Generic float/center rules for picker-style windows. Rules tied to the
-- old flake's nos/1Password/lazydocker/Windows-VM integrations were dropped
-- since none of those are set up on this machine.
local windows = {
	{ class = "xdg-desktop-portal-gtk" },
	{ class = "termfilechooser" },
}

for _, window in ipairs(windows) do
	hl.window_rule({
		match = window.title and { title = window.title } or { class = window.class },
		float = true,
		center = true,
		size = window.size or { 1000, 650 },
	})
end
