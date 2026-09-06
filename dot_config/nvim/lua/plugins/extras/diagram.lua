-- render Markdown diagrams only where Kitty's graphics protocol is available.
return {
	"3rd/diagram.nvim",
	enabled = not vim.g.neovide,
	ft = { "markdown" },
	dependencies = { "3rd/image.nvim" },
	opts = {},
}
