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
does nothing when every managed package is already installed. AUR packages
remain outside this repository.
