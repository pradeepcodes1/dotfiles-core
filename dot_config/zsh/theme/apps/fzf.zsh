# recolor fzf repeatedly without accumulating duplicate options.
# Fzf theme integration

# Store base opts once (without colors) to avoid accumulation on theme switch
(( ${+_FZF_BASE_OPTS} )) || export _FZF_BASE_OPTS="$FZF_DEFAULT_OPTS"

# Selection and muted text have independent roles even when ANSI gray equals white.
export FZF_DEFAULT_OPTS="$_FZF_BASE_OPTS \
  --color=fg:$theme_ui_fg,bg:$theme_ui_bg,hl:$theme_ui_magenta \
  --color=fg+:$theme_ui_selection_fg,bg+:$theme_ui_selection,hl+:$theme_ui_selection_fg \
  --color=info:$theme_ui_muted,prompt:$theme_ui_blue,pointer:$theme_ui_blue \
  --color=marker:$theme_ui_green,spinner:$theme_ui_blue,header:$theme_ui_muted,border:$theme_ui_border"
