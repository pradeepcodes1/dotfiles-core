local M = {}

local project_state = require("project.state")

function M.setup()
	require("lsp.project_lsp").setup()
	project_state.set_open(false)

	vim.api.nvim_create_autocmd("VimEnter", {
		desc = "Restore a project explicitly launched by the project picker",
		once = true,
		callback = function()
			-- Only picker-launched instances receive this marker, so ordinary files stay file-only.
			local requested_session = vim.env.NVIM_PROJECT_SESSION
			if requested_session and requested_session ~= "" then
				vim.env.NVIM_PROJECT_SESSION = nil
				project_state.set_open(true, requested_session:match("^([^|]+)"))
				vim.schedule(function()
					if
						not require("auto-session").restore_session(
							requested_session,
							{ is_startup_autorestore = true, show_message = false }
						)
					then
						project_state.set_open(false)
					end
				end)
			end
		end,
	})
end

return M
