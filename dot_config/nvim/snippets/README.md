# Snippets

Hand-written snippets, completed by blink.cmp's built-in `snippets` source and
expanded by Neovim's own `vim.snippet`. Wired up in
`lua/dotfiles/plugins/lsp/blink.lua`, which points the provider's `search_paths`
at this directory. There is no snippet engine plugin (no LuaSnip, no
friendly-snippets); nothing outside this directory contributes.

## Adding snippets

One file per filetype, named after the filetype: `lua.json`, `python.json`,
`go.json`. `all.json` is the global file -- its snippets are offered in every
buffer (blink's `global_snippets` default is `{ "all" }`).

blink discovers files by scanning this directory, so a new filetype is a new
file and nothing else -- there is deliberately no `package.json` manifest to
keep in sync. (blink prefers a `package.json` when it finds one and falls back
to scanning; adding one would turn every new file into a two-file edit.)

## Format

VSCode snippet JSON. Strict JSON, parsed with `vim.json.decode` -- no comments,
no trailing commas, or the whole file is dropped with an error notification.

```json
{
  "Snippet name": {
    "prefix": "trigger",
    "body": ["line one $1", "line two $0"],
    "description": "shown in the documentation window"
  }
}
```

`body` is a string or an array of lines. `$1`, `$2`, ... are tabstops (`<Tab>`
and `<S-Tab>` jump between them), `$0` is where the cursor lands last,
`${1:default}` is a placeholder. `prefix` may be an array to give one snippet
several triggers.

Variables are expanded too: `$LINE_COMMENT`, `$TM_FILENAME_BASE`,
`$CURRENT_YEAR`, `$RELATIVE_FILEPATH`, `$UUID`, `$CLIPBOARD` and the rest of the
VSCode set.

## Deployment

The `.json` files are chezmoi-managed like the rest of the config, so
`chezmoi apply` puts them at `~/.config/nvim/snippets/`. This README is not --
`.chezmoiignore` drops every `**/*.md`, so it stays source-side documentation.

blink reads a filetype's snippets once and caches them, so editing a file that
the running session has already used needs a restart to take effect.
