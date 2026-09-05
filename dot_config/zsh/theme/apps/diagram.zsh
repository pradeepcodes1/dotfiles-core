# make rendered diagrams legible against the terminal background.
# Diagram theme integration
_DIAGRAM_MMDC_BG="${bg}"

if [[ "$_DOTFILES_THEME_MODE" == "dark" ]]; then
  _DIAGRAM_MMDC_THEME="dark"
else
  _DIAGRAM_MMDC_THEME="default"
fi
