-- prefer Homebrew/mise binaries while retaining Mason installations as fallbacks.
return {
	"williamboman/mason.nvim",
	opts = {
		PATH = "append",
	},
}
