# make rendered diagrams legible against opaque and transparent terminals.
# Diagram theme integration
if [[ "$_DOTFILES_THEME_TRANSPARENT" == "1" ]]; then
  _DIAGRAM_MMDC_BG="transparent"
else
  _DIAGRAM_MMDC_BG="${bg}"
fi

if [[ "$_DOTFILES_THEME_MODE" == "dark" ]]; then
  _DIAGRAM_MMDC_THEME="dark"
else
  _DIAGRAM_MMDC_THEME="default"
fi
