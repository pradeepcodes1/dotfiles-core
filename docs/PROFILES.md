# Profiles

The public source has one package-managed profile: `minimal-linux` on Arch
Linux. macOS may consume the portable files, but machine-specific package and
application configuration belongs to a separate local overlay.

The package list is assembled from:

- `.chezmoitemplates/packages/pacman/common.tmpl`
- `.chezmoitemplates/packages/pacman/minimal-linux.tmpl`

The installer runs `pacman -S --needed --noconfirm` against official repository
packages. AUR policy and full-system upgrades remain explicit operations.
