vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
	group = vim.api.nvim_create_augroup("disable_spell_checking", { clear = true }),
	callback = function()
		vim.opt_local.spell = false
	end,
})
