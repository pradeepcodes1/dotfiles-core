# Dotfiles Theme System

Centralized color definitions for CLI tools. Each theme has one source file that still drives app colors across:

- Kitty theme selection (mapped to kitty's themes kitten)
- Shell prompt (Zsh)
- Tmux status bar
- Neovim colorscheme + lualine
- Yazi file manager
- fzf fuzzy finder

## Usage

```bash
theme                 # fzf picker for all themes
theme gogh            # browse, import, and apply a Gogh terminal palette
theme gogh refresh    # refresh the cached Gogh catalog, then browse
theme dark            # fzf picker for dark themes only
theme light           # fzf picker for light themes only
theme toggle          # quick switch between default dark/light
theme <name>          # switch to specific theme
theme list            # list available themes
theme status          # show current theme info
theme reset           # revert to system-detected theme
```

`theme gogh` downloads Gogh's palette JSON on first use, never its executable
installer scripts. The catalog is cached under `~/.cache/dotfiles/gogh/` and a
selected palette is converted into a regular shell theme under
`~/.local/share/dotfiles/gogh/themes/`. Imported themes persist across shells
and appear in the normal `theme`, `theme dark`, `theme light`, and `theme list`
commands. Use `theme gogh refresh` when you want a newer catalog.

Known names reuse the curated file's Neovim, bat, eza, and Yazi mappings. For
other Gogh palettes, Kitty and Yazi receive generated color configs, Neovim and
lualine use the generated `dotfiles-gogh` themes, and bat/delta plus eza emit
ANSI colors so they inherit the same terminal palette. The import is therefore
complete without a per-app questionnaire or manual mapping step.

## Adding a New Theme

Create `<theme-name>.sh` with the following structure:

```sh
# Theme: <theme-name>
# Mode: dark|light
# Transparent: 1|0

# Legacy terminal color values (kept while Kitty moves to the themes kitten)
bg="#..."
fg="#..."

# Normal ANSI colors
black="#..."
red="#..."
green="#..."
yellow="#..."
blue="#..."
magenta="#..."
cyan="#..."
white="#..."

# Bright ANSI colors
bright_black="#..."
bright_red="#..."
bright_green="#..."
bright_yellow="#..."
bright_blue="#..."
bright_magenta="#..."
bright_cyan="#..."
bright_white="#..."

# Prompt colors (used by Zsh)
prompt_dir="#..."       # current directory
prompt_branch="#..."    # branch, ahead, and clean Git state
prompt_unstaged="#..."  # behind, unstaged, untracked, and conflict state
prompt_staged="#..."    # staged changes and Git operations in progress
prompt_arrow="#..."     # prompt arrow (❯)
prompt_path="#..."      # muted prompt metadata, timer, and stash state

# UI colors (used by Tmux)
ui_bg="#..."            # status bar background
ui_fg="#..."            # status bar foreground
ui_accent="#..."        # accent color
ui_border="#..."        # pane border
ui_active="#..."        # active window/pane
ui_inactive="#..."      # inactive window/pane

# Neovim (optional - for themes needing special handling)
nvim_colorscheme="..."  # vim colorscheme name
nvim_lualine="..."      # lualine theme name
nvim_background="..."   # "dark" or "light" (only if colorscheme needs it)

# Foreign theme names (apps that carry their own theme registries)
kitty_theme="..."       # kitty-themes name, applied via the themes kitten
bat_theme="..."         # bat syntax theme; delta reuses this value
eza_theme="..."         # file name under eza-themes/themes/ (no .yml)
yazi_flavor="..."       # directory under yazi/flavors/ (no .yazi)
```

### Foreign Theme Names

Apps like kitty, bat, delta, eza, and yazi cannot be handed hex colors — they
ship their own theme registries and accept only a theme _name_. Those names live
here, next to the palette they belong to, rather than in per-app lookup tables.
Adding a theme is therefore a single-file change.

Every key above is optional and falls back to a sane default, but an omitted key
means that app silently keeps its default rather than matching your theme, so
fill in all four. `delta` has no key of its own by design: it renders with bat's
syntax themes, so it reads `bat_theme`.

## Header Comments

The first three lines must be:

```sh
# Theme: <name>
# Mode: dark|light
# Transparent: 1|0
```

These are parsed by `theme.zsh` to determine theme metadata:

- **Mode**: Controls system theme detection fallback
- **Transparent**: If `1`, enables transparent background in Neovim

## Color Guidelines

### Legacy Terminal Color Values

Follow standard ANSI color semantics:

- `black/bright_black`: backgrounds, muted text
- `red/bright_red`: errors, deletions
- `green/bright_green`: success, additions
- `yellow/bright_yellow`: warnings, modifications
- `blue/bright_blue`: info, links
- `magenta/bright_magenta`: special, search
- `cyan/bright_cyan`: secondary info
- `white/bright_white`: primary text

### Prompt Colors

- Keep `prompt_dir` and `prompt_arrow` visually prominent
- Use semantic colors: red for attention/error states, yellow for staged work
  and operations, and green for clean/ahead state
- `prompt_path` should be muted (it colors secondary prompt metadata)

### UI Colors

- `ui_active` should contrast well with `ui_bg`
- `ui_inactive` should be subtle but visible
- `ui_border` typically matches `ui_inactive`

## Curated Themes

| Theme                 | Mode  | Transparent |
| --------------------- | ----- | ----------- |
| kanagawa-dragon       | dark  | yes         |
| kanagawa-wave         | dark  | yes         |
| kanagawa-lotus        | light | no          |
| catppuccin-mocha      | dark  | yes         |
| catppuccin-latte      | light | no          |
| gruvbox-dark          | dark  | yes         |
| gruvbox-light         | light | no          |
| everforest-dark       | dark  | yes         |
| everforest-light      | light | no          |
| nightfox              | dark  | yes         |
| dawnfox               | light | no          |
| bearded-monokai-black | dark  | yes         |
| brogrammer            | dark  | yes         |

## How It Works

1. `theme.zsh` resolves the selected color file from the curated directory,
   then from the generated Gogh directory.
2. All variables become available in the shell.
3. App-specific integrations are applied:
   - **Kitty**: its themes kitten for curated mappings, or a generated
     `current-theme.conf` for Gogh palettes
   - **Tmux**: `~/.config/tmux/themes/current.conf`
4. Environment variables are exported for apps that read them:
   - `_DOTFILES_THEME_NAME`
   - `_DOTFILES_THEME_MODE`
   - `_DOTFILES_THEME_TRANSPARENT`
   - `_DOTFILES_NVIM_COLORSCHEME`
   - `_DOTFILES_NVIM_LUALINE`
   - `_DOTFILES_NVIM_BACKGROUND`

## Persistence

Theme choice is persisted to `~/.local/state/dotfiles/theme` and restored on
new shells. Generated Gogh themes are runtime data rather than chezmoi-managed
source files; choosing one does not dirty the dotfiles repository.
Use `theme reset` to clear and revert to macOS system appearance detection.
