# Theme system

Gogh's validated JSON catalog is the single source of terminal palettes. The
repository contains adapters, not hand-maintained palette files.

```sh
theme          # browse, import, and apply any Gogh palette
theme refresh  # refresh the Gogh catalog before browsing
theme status   # show the current palette and mode
theme reset    # return to the system-appropriate default
```

The catalog is cached at `~/.cache/dotfiles/gogh/themes.json`. Each selection
is compiled to `~/.local/share/dotfiles/gogh/themes/gogh-<slug>.sh`; these files
are runtime data and are not managed by chezmoi. The generated file carries the
exact Gogh ANSI palette plus deterministic semantic colors for the prompt and
tmux. Adapters derive the remaining application configuration from that same
palette:

- Kitty and Yazi receive literal generated color configuration.
- Neovim and lualine use the repository's `dotfiles-gogh` renderers.
- bat and delta use bat's ANSI theme.
- eza uses its generic ANSI theme.
- Zsh, tmux, and fzf use semantic colors derived from Gogh's ANSI slots.

The system defaults are Gogh's Kanagawa Dragon and Kanagawa Lotus. If a
default or persisted generated file is missing, the shell re-imports it by
slug from the cached catalog, fetching the catalog when necessary. A fresh
machine therefore needs `curl`, `jq`, and network access for its first theme;
after import, normal startup and switching among imported themes are offline.

Theme state is persisted at `~/.local/state/dotfiles/theme`. Selections left by
the former curated-file system are migrated automatically to their `gogh-`
names when the same slug exists in Gogh. Generated files from the former system
are also detected by format version and recompiled without curated mappings.
