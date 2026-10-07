# Snippets

Hand-written snippets, completed by blink.cmp's built-in `snippets` source and
expanded by Neovim's own `vim.snippet`. There is no snippet engine plugin (no
LuaSnip, no friendly-snippets); nothing outside this directory contributes.

The files are VSCode snippet JSON, but they are not meant to be edited by hand:
[nvim-scissors](https://github.com/chrisgrieser/nvim-scissors) writes them.

## Adding and editing snippets

From a buffer of the filetype you want the snippet for:

| Key          | Action                                                         |
| ------------ | -------------------------------------------------------------- |
| `<leader>ia` | Add a snippet (in visual mode, the selection becomes its body) |
| `<leader>ie` | Pick a snippet for this filetype (or `all`) and edit it        |

`:ScissorsAddNewSnippet` and `:ScissorsEditSnippet` do the same. In the popup,
the top lines are prefixes (one per line), the rest is the body; `<CR>` saves,
`q` cancels, `?` lists the other keys. Saving hot-reloads blink, so the change
is live immediately. The first snippet for a new filetype creates `<ft>.json`
and registers it in `package.json`; that one needs a Neovim restart.

Body syntax: `$1`, `$2`, ... are tabstops (`<Tab>`/`<S-Tab>` jump), `$0` is
where the cursor lands last, `${1:default}` is a placeholder. VSCode variables
such as `$LINE_COMMENT`, `$TM_FILENAME_BASE` and `$CURRENT_YEAR` are expanded.

## Layout

- `package.json` maps filetypes to files. nvim-scissors requires it, and blink
  reads it in preference to scanning the directory, so a snippet file that is
  not listed here is ignored. `all.json` is offered in every buffer.
- `*.json` are formatted the way scissors writes them (sorted keys, two-space
  indent, no final newline). Prettier and end-of-file-fixer skip them in
  `.pre-commit-config.yaml` so saves do not produce reformatting churn.

## Deployment

This directory is not copied by chezmoi. `dot_config/nvim/symlink_snippets.tmpl`
makes `~/.config/nvim/snippets` a symlink to it, so scissors' writes land in the
checkout and show up in `git status` with no `chezmoi re-add` step.
