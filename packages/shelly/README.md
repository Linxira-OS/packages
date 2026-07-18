# Shelly Packaging Notes

This recipe builds Shelly 2.4.1.4 from the fixed upstream commit
`9b96a7efb7fcd37e5331710edfc5f22db22f2323`, not from CachyOS, AUR, or the
Seafoam binary repository. The upstream tag commit is unsigned; its downloaded
source archive is pinned by SHA-256 in the PKGBUILD.

`linxira-safety-policy.patch` removes Shelly's GUI control for deleting
`/var/lib/pacman/db.lck`, its generic privileged-system-command path, and its
unverified startup download of icon archives from GitHub. Normal package
transactions continue through Shelly's own CLI and the packaged Polkit action.

The package intentionally does not ship the unrelated `shelly-keys` utility.
Fresh user configuration disables AUR, Flatpak, and AppImage integration; AUR
requires a confirmation in the GUI, and Flatpak remotes are only added through
an explicit user action. Background tray checks are also disabled for a fresh
profile and, when enabled, only query package sources enabled in that profile.
