-- minimal, portable neovim config. no plugin manager: uses nvim's built-in
-- vim.pack (0.12+). works on any machine with just this one file + git + nvim.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = "yes"
o.updatetime = 250
o.undofile = true
o.clipboard = "unnamedplus"
o.splitright = true
o.splitbelow = true
o.scrolloff = 8
o.termguicolors = true

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank()
	end,
})

-- plugins: keep this list short. add a url, run :Pack sync.
vim.pack.add({
	"https://github.com/nvim-treesitter/nvim-treesitter",
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/folke/tokyonight.nvim",
	"https://github.com/folke/snacks.nvim",
	"https://github.com/echasnovski/mini.icons",
	"https://github.com/MagicDuck/grug-far.nvim",
	"https://github.com/akinsho/bufferline.nvim",
	"https://github.com/folke/which-key.nvim",
	"https://github.com/MunifTanjim/nui.nvim",
	"https://github.com/folke/noice.nvim",
	"https://github.com/nvim-lualine/lualine.nvim",
})

vim.cmd.colorscheme("tokyonight-night")

-- treesitter: highlight only, install parsers on demand
require("nvim-treesitter").install({ "lua", "vim", "vimdoc", "nix", "bash", "markdown" })
vim.api.nvim_create_autocmd("FileType", {
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})

-- lsp: enable any server whose binary is on $PATH (install servers via nix/system)
vim.lsp.enable({ "lua_ls", "nil_ls", "pyright", "ts_ls", "bashls" })
vim.diagnostic.config({ virtual_text = true })

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local bufopts = { buffer = args.buf }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
	end,
})

require("mini.icons").setup()
require("which-key").setup() -- shows a popup of available keymaps on <leader>
require("which-key").add({
	{ "<leader>b", group = "buffer" },
	{ "<leader>f", group = "find" },
	{ "<leader>g", group = "git" },
	{ "<leader>q", group = "quit" },
	{ "<leader>s", group = "search" },
	{ "<leader>t", group = "tabs" },
})

-- snacks: file picker, file explorer (replaces netrw by default), lazygit
require("snacks").setup({
	explorer = {}, -- enables snacks explorer as netrw replacement
	picker = {
		sources = {
			explorer = { layout = { preview = "main" } },
		},
	},
})
vim.keymap.set("n", "<leader><leader>", function() Snacks.picker.files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function() Snacks.picker.grep() end, { desc = "Grep" })
vim.keymap.set("n", "<leader>fb", function() Snacks.picker.buffers() end, { desc = "Buffers" })
-- preview ("main") needs some other window to render into; if the explorer
-- is the only window left, open one so refocusing can still show a preview
local function ensure_main_window()
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
		if not ft:match("^snacks") then
			return
		end
	end
	vim.cmd("vsplit")
end

-- explorer and grug-far are mutually exclusive; only one may be open
local function close_grug_far()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].filetype == "grug-far" then
			require("grug-far").kill_instance(buf)
		end
	end
end

vim.keymap.set("n", "<leader>e", function()
	local explorer = Snacks.picker.get({ source = "explorer" })[1]
	if explorer then
		ensure_main_window()
		explorer:focus()
		explorer:show_preview()
	else
		close_grug_far()
		Snacks.explorer()
	end
end, { desc = "Focus explorer" })
vim.keymap.set("n", "<leader>E", function()
	close_grug_far()
	Snacks.explorer()
end, { desc = "Toggle explorer" })
vim.keymap.set("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "LazyGit" })

-- grug-far: project-wide search and replace. Single reused instance, opened
-- left of any snacks explorer, same width as the explorer sidebar (40 cols).
local GRUG_FAR_INSTANCE = "search"
local function open_grug_far(prefills)
	local explorers = Snacks.picker.get({ source = "explorer" })
	for _, picker in ipairs(explorers) do
		picker:close()
	end
	local function do_open()
		local grug_far = require("grug-far")
		if grug_far.has_instance(GRUG_FAR_INSTANCE) then
			local inst = grug_far.get_instance(GRUG_FAR_INSTANCE)
			inst:open()
			if prefills then
				inst:update_input_values(prefills, true)
			end
		else
			grug_far.open({
				instanceName = GRUG_FAR_INSTANCE,
				prefills = prefills,
				windowCreationCommand = "topleft 40vsplit",
				openTargetWindow = { preferredLocation = "right" },
				-- unlisted, so Snacks.bufdelete never picks it as a fallback buffer
				-- for some *other* window (e.g. one showing an opened match)
				transient = true,
			})
		end
		vim.wo.winfixwidth = true -- keep the width fixed; grug-far doesn't set this itself, unlike snacks' sidebar
	end
	if #explorers > 0 then
		-- picker:close() tears down its windows on the next tick (vim.schedule);
		-- opening immediately races that and the split settles at half width
		vim.schedule(do_open)
	else
		do_open()
	end
end
vim.keymap.set("n", "<leader>sg", function() open_grug_far() end, { desc = "Search (grug-far)" })
vim.keymap.set("n", "<leader>sr", function()
	open_grug_far({ search = vim.fn.expand("<cword>") })
end, { desc = "Search & replace word under cursor" })

-- closing a grug-far buffer via the generic Snacks.bufdelete swaps in another
-- grug-far buffer (each search opens a new, unrelated listed buffer). Use the
-- plugin's own teardown instead so <C-w>/<leader>bd close it properly.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "grug-far",
	callback = function(args)
		local close = function() require("grug-far").kill_instance(0) end
		vim.keymap.set("n", "<C-w>", close, { buffer = args.buf, nowait = true })
		vim.keymap.set("n", "<leader>bd", close, { buffer = args.buf })
	end,
})

-- bufferline: LazyVim-style buffer tabs
require("bufferline").setup({
	options = {
		diagnostics = "nvim_lsp",
		always_show_bufferline = false,
		offsets = {
			{ filetype = "snacks_picker_list", text = "Explorer", highlight = "Directory", text_align = "left" },
		},
		custom_filter = function(buf)
			return vim.bo[buf].filetype ~= "grug-far" and vim.api.nvim_buf_get_name(buf) ~= ""
		end,
	},
})
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete buffer" })

vim.keymap.set("n", "<C-w>", function() Snacks.bufdelete() end, { desc = "Close buffer", nowait = true })

vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit neovim" })

vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>write<cr>", { desc = "Save file" })

-- noice: styled cmdline, popup near the top instead of the bottom command line
require("noice").setup({
	presets = {
		command_palette = true, -- cmdline + popupmenu near the top of the screen
		bottom_search = true,
		long_message_to_split = true,
		lsp_doc_border = true,
	},
})

-- lualine: LazyVim-style statusline footer, single bar across all splits
vim.opt.laststatus = 3
require("lualine").setup({
	options = {
		theme = "tokyonight",
		globalstatus = true,
		component_separators = "",
		section_separators = "",
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = { "branch", "diff" },
		lualine_c = { "diagnostics", { "filetype", icon_only = true }, { "filename", path = 1 } },
		lualine_x = {},
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
})