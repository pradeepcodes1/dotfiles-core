# recolor fzf repeatedly without accumulating duplicate options.
# Fzf theme integration

# Store base opts once (without colors) to avoid accumulation on theme switch
(( ${+_FZF_BASE_OPTS} )) || export _FZF_BASE_OPTS="$FZF_DEFAULT_OPTS"

local fzf_bg="$bg"

export FZF_DEFAULT_OPTS="$_FZF_BASE_OPTS \
  --color=fg:$fg,bg:$fzf_bg,hl:$magenta \
  --color=fg+:$fg,bg+:$ui_inactive,hl+:$ui_active \
  --color=info:$bright_black,prompt:$ui_accent,pointer:$ui_accent \
  --color=marker:$green,spinner:$ui_accent,header:$bright_black"
