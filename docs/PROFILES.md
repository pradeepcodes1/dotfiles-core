# Profiles

The public source has one package-managed profile: `minimal-linux` on Arch
Linux. macOS may consume the portable files, but machine-specific package and
application configuration belongs to a separate local overlay.

The package list is assembled from:

- `.chezmoitemplates/packages/pacman/common.tmpl`
- `.chezmoitemplates/packages/pacman/minimal-linux.tmpl`

The installer uses `pacman -T` to identify missing packages. If any are absent,
it runs `pacman -Syu --needed --noconfirm` so database refresh, full system
upgrade and package installation happen in one supported Arch transaction. It
does nothing when every managed package is already installed. AUR packages are
listed separately, in `.chezmoitemplates/packages/aur/common.tmpl`, and
installed by paru or yay rather than pacman. The helper is not bootstrapped
here: without one the step warns and skips. Only packages with no official
repository build belong in that list.

## Yazi packages

`dot_config/yazi/package.toml` pins the Yazi plugins and flavors, but chezmoi
only deploys that manifest -- the packages themselves are fetched by
`ya pkg install`, which the apply runs for you. This matters because
`dot_config/yazi/init.lua` calls `require("git"):setup()`: without the packages
Yazi aborts at launch with `failed to load plugin from .../plugins/git.yazi`.

The installer compares the manifest against the deployed package directories and
runs `ya pkg install` only when one is missing or incomplete, because that
command refetches every package on every invocation. It skips silently when `ya`
is unavailable, which is the normal state on macOS where this source is applied
before Homebrew installs Yazi; the private overlay covers that case. Set
`CHEZMOI_SKIP_YAZI_PACKAGES` to skip the step, for instance when applying
offline.
