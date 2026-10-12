-- local fill-in-the-middle completion through ollama, used instead of Copilot
-- when init.lua sets vim.g.ai_completion = "minuet". The blink provider is
-- declared in plugins/lsp/blink.lua; ollama itself is installed and the model
-- pulled by the macOS overlay's setup script.
return {
	{
		"milanglacier/minuet-ai.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		-- A preview window is read-only, so completion there is wasted inference.
		enabled = not vim.g.nvim_preview and vim.g.ai_completion == "minuet",
		lazy = true,
		opts = {
			-- The base (not instruct) model speaks the FIM template that ollama's
			-- OpenAI-compatible /v1/completions endpoint expects.
			provider = "openai_fim_compatible",
			-- A 1.5B model gives one usable candidate; more only add latency.
			n_completions = 1,
			-- Characters of surrounding code sent per request. Small keeps a
			-- 1.5B model fast and inside its useful attention range.
			context_window = 1024,
			provider_options = {
				openai_fim_compatible = {
					-- ollama ignores the key, but minuet requires an env var name
					-- that is set; TERM always is.
					api_key = "TERM",
					name = "Ollama",
					end_point = "http://localhost:11434/v1/completions",
					model = "qwen2.5-coder:1.5b",
					optional = {
						max_tokens = 64,
						top_p = 0.9,
					},
				},
			},
		},
	},
}
