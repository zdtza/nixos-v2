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
