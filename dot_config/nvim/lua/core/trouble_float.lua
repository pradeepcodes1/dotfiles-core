-- move focus onto the first result because Trouble floats initially select their container.
local M = {}

function M.get(load)
	if package.loaded.trouble or load then
		return require("trouble")
	end
end

function M.focus_first_item(view)
	if not view or type(view.wait) ~= "function" then
		return view
	end

	view:wait(function()
		if not view.win or type(view.win.valid) ~= "function" or not view.win:valid() then
			return
		end

		local loc = view:at() or {}
		if loc.item then
			return
		end

		view:action("next")
	end)

	return view
end

return M
