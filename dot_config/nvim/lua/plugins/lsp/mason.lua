-- prefer Homebrew/mise binaries while retaining Mason installations as fallbacks.
return {
	"mason-org/mason.nvim",
	opts = {
		PATH = "append",
	},
}
