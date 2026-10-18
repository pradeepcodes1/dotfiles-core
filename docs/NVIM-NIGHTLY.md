# Neovim nightly

<!-- Nightly lives beside the Homebrew stable build so `nvim` stays dependable while trying HEAD. -->

Stable `nvim` comes from Homebrew. The nightly binary is a separate, unmanaged
install that chezmoi and mise do not track. chezmoi manages only the
`nvim-nightly` wrapper and the `~/.config/nvim-nightly` → `nvim` config link.

| Command        | Binary                                                                                                            |
| -------------- | ----------------------------------------------------------------------------------------------------------------- |
| `nvim`         | `/opt/homebrew/bin/nvim` (stable)                                                                                 |
| `nvim-nightly` | `~/.local/bin/nvim-nightly` (wrapper) → `~/.local/opt/nvim-macos-arm64/bin/nvim` with `NVIM_APPNAME=nvim-nightly` |

## Install / update

Re-running this replaces the existing nightly with the latest build.

```sh
mkdir -p ~/.local/opt ~/.local/bin && cd ~/.local/opt
curl -fsSLO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz
xattr -c nvim-macos-arm64.tar.gz   # strip macOS quarantine so the binary runs
rm -rf nvim-macos-arm64 && tar xzf nvim-macos-arm64.tar.gz && rm nvim-macos-arm64.tar.gz
nvim-nightly --version
```

## Remove

```sh
rm -rf ~/.local/opt/nvim-macos-arm64
rm -rf ~/.local/share/nvim-nightly ~/.local/state/nvim-nightly ~/.cache/nvim-nightly
```

## Notes

- Both binaries share one config (via the `~/.config/nvim-nightly` link) and
  so one `lazy-lock.json`. Everything else is separate: nightly keeps its
  plugins, sessions, shada, and undo history under `~/.local/share/nvim-nightly`
  and `~/.local/state/nvim-nightly`. That keeps a session saved by nightly
  away from stable, which fails to restore it when it sets options stable
  doesn't have (e.g. `E518: Unknown option: nofollow`). The first nightly
  launch installs its own plugins.
- Changes since 0.12: `:h news` inside nightly, or
  <https://neovim.io/doc/user/news.html>. Ones that touch muscle memory:
  `Q` now adds a multicursor instead of replaying the last macro, and
  `:restart` now restores the session (`:restart!` for the old behavior).
