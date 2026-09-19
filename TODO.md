# TODO

<!-- Verify that FFF's experimental preview toggle and resizing remain comfortable in daily use. -->

- [ ] Try the experimental FFF preview toggle and adaptive width; if it does not work well, simplify to preview disabled by default.

<!-- Evaluate the new highlighting integration during regular blame review. -->

- [ ] Try out diffs.nvim.

<!-- Keep the cross-frontend evidence here so the layout bug can be isolated and filed upstream. -->

- [ ] Investigate the flash when opening Snacks Explorer: in both Neovide and terminal Neovim under Kitty, the editor briefly uses an approximately half-width split before settling beside the 40-column sidebar. Reproduce with a minimal Snacks configuration and prioritize Snacks/Neovim layout handling over frontend rendering, then file an issue if it persists. Related reports: [snacks.nvim #1308](https://github.com/folke/snacks.nvim/issues/1308), [Neovide #1947](https://github.com/neovide/neovide/issues/1947), and [Neovide #2385](https://github.com/neovide/neovide/issues/2385).

<!-- Revisit scrolling behavior when the option becomes available in the stable release. -->

- [ ] Try the `scrolloffpad` option in Neovim 0.13.

<!-- Yazi supports only parent/current/preview in its built-in manager layout. -->

- [ ] Prototype a custom Yazi manager renderer with grandparent, parent, current, and preview columns.

<!-- These remain candidates only when their repeated workflows justify a persistent mode. -->

- [ ] Add a debugging Hydra for continue, stepping, breakpoints, restart, and termination.
- [ ] Add a diagnostics Hydra for navigation, severity filtering, and diagnostic details.

<!-- The old adapter wrote `theme` into ~/.claude.json, which Claude Code rewrites from an in-memory cache, so the value was always dropped within seconds. Custom theme files avoid the conflict because the adapter would own the file outright. -->

- [ ] Reinstate Claude Code theming through a custom theme file instead of the retired `~/.claude.json` adapter. Write `~/.claude/themes/dotfiles.json` as `{"name": ..., "base": "dark"|"light", "overrides": {...}}`; overrides accept `#rrggbb` and only keys present in the base theme, so the roles `ui-colors.py` already derives map directly onto `text`, `background`, `subtle`, `suggestion`, `success`, `error`, `warning`, `selectionBg`, and the `diffAdded`/`diffRemoved`/`diffAddedDimmed`/`diffRemovedDimmed`/`diffAddedWord`/`diffRemovedWord` set. Selecting it once with `/theme` persists `theme: "custom:dotfiles"` through Claude Code's own writer; after that the adapter only has to rewrite the colors. Verified against Claude Code 2.1.267.
