-- Static monitor list for this machine (Legion laptop, built-in display
-- only). The old flake generated this from per-host Nix config; that
-- generation wasn't ported, so it's just inlined here. Add entries for
-- external monitors as needed.
local configured_monitors = {
	{
		output = "eDP-1",
		mode = "1920x1080@60",
		position = "0x0",
		scale = 1,
		workspaces = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
	},
}

local M = {}
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

function M.scroll_workspace(offset)
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

function M.toggle_aspect_ratio()
	aspect_ratio_enabled = not aspect_ratio_enabled
	hl.config({
		layout = {
			single_window_aspect_ratio = aspect_ratio_enabled and { 16, 9 } or { 0, 0 },
		},
	})
end

for _, monitor in ipairs(configured_monitors) do
	assign_workspaces(monitor.output, monitor.workspaces)
	hl.monitor({
		output = monitor.output,
		mode = monitor.mode,
		position = monitor.position,
		scale = monitor.scale,
	})
end

table.sort(all_workspaces)

return M
