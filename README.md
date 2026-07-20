# Linxira OS Packages

Official Arch Linux package definitions and repository publishing workflow for
Linxira OS.

Maintainer recovery, workstation rebuild, and release handoff instructions are
in [`docs/MAINTAINER_HANDOFF.md`](docs/MAINTAINER_HANDOFF.md).

## Repository layout

- `packages/`: one pinned PKGBUILD per Linxira-owned package or explicitly
  adopted source-built integration package
- `scripts/check-boundaries.sh`: rejects accidental replacement of upstream
  CachyOS packages and tool identities
- `.github/workflows/packages.yml`: isolated Arch container build, signing,
  `repo-add`, and GitHub Pages deployment

## Trust model

Every source package is pinned to a Git commit or immutable source archive.
Each CI matrix job starts from a fresh official `archlinux:base-devel` image
and runs a clean `makepkg` build.
Publishing is disabled unless the repository has these secrets:

- `LINXIRA_GPG_PRIVATE_KEY`: armored export of a dedicated package-signing
  subkey
- `LINXIRA_GPG_FINGERPRINT`: full 40-hex fingerprint of that key

The exported CI signing subkey should not have a passphrase. Keep the primary
certification key offline. Package files and repository databases are signed;
GitHub Pages only receives public packages, signatures, databases, and the
public key.

After the key is configured, run the `Build and publish packages` workflow with
`publish` enabled. The repository URL is:

```ini
[linxira]
SigLevel = Required DatabaseOptional
Server = https://linxira-os.github.io/packages/$arch
```

Do not add this stanza to an ISO until `linxira-keyring` is built from the
approved public key and installed before the repository is enabled.

## Software Discovery

Once `[linxira]` is enabled, pacman and supported graphical frontends can
discover Linxira packages through normal repository metadata. Linxira Catalog
provides reviewed workstation and scientific profiles. Linxira Welcome displays
that catalog and fixed system entry points without performing package
transactions. Shelly provides post-install management of Arch packages, AUR
packages, Flatpaks, and AppImages.

Third-party recommended applications are installed from their declared source
(Arch, Flatpak, vendor repository, or reviewed Linxira package). Listing an
application does not make Linxira its binary redistributor or maintainer.

## Shelly Exception

`shelly` is a source-built GPL-3.0 package maintained as an explicit Linxira
packaging exception. Its recipe pins an upstream commit and source checksum,
removes the unsafe GUI action that deletes pacman's lock file, and never uses
CachyOS, AUR, or Seafoam binary repositories as build inputs.

Shelly is optional post-install software. It is not an installer dependency,
does not run during Calamares installation, and does not automatically enable
AUR, Flathub, or any third-party repository.

## Calamares Exception

`calamares` is an explicitly adopted installer framework package. Its recipe
builds the official 3.3.14 release archive pinned by the SHA-256 published
upstream. It does not consume the CachyOS fork, package, or repository.

Distribution-specific storage policy, target package manifests, branding, and
offline repository configuration remain in the Direct-Arch ISO profile. The
Calamares package contains the framework and upstream modules only.

## Linxira Update

`linxira-update` is the Linxira-owned continuation of the GPL-3.0
Cachy-Update/Arch-Update code line. It is built from the pinned public Linxira
source commit and installs only Linxira command, desktop, state, icon, and
systemd identities. Official pacman repositories are the default update scope;
AUR and Flatpak updates require explicit user opt-in.

## Gaming Manager

`linxira-gaming-manager` is a user-scoped library and compatibility workspace.
It discovers Steam and imported games, launches through fixed argument arrays,
detects external compatibility tools, and delegates encrypted backups to
restic. It contains no package manager, system service, Polkit policy, or root
helper.
