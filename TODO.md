# TODO

<!-- Keep the cross-frontend evidence here so the layout bug can be isolated and filed upstream. -->

- [ ] Investigate the flash when opening Snacks Explorer: in both Neovide and terminal Neovim under Kitty, the editor briefly uses an approximately half-width split before settling beside the 40-column sidebar. Reproduce with a minimal Snacks configuration and prioritize Snacks/Neovim layout handling over frontend rendering, then file an issue if it persists. Related reports: [snacks.nvim #1308](https://github.com/folke/snacks.nvim/issues/1308), [Neovide #1947](https://github.com/neovide/neovide/issues/1947), and [Neovide #2385](https://github.com/neovide/neovide/issues/2385).

<!-- Revisit scrolling behavior when the option becomes available in the stable release. -->

- [ ] Try the `scrolloffpad` option in Neovim 0.13.

<!-- Yazi supports only parent/current/preview in its built-in manager layout. -->

- [ ] Prototype a custom Yazi manager renderer with grandparent, parent, current, and preview columns.

<!-- These remain candidates only when their repeated workflows justify a persistent mode. -->

- [ ] Add a debugging Hydra for continue, stepping, breakpoints, restart, and termination.
- [ ] Add a diagnostics Hydra for navigation, severity filtering, and diagnostic details.
