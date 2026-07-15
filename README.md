# Linxira OS Packages

Official Arch Linux package definitions and repository publishing workflow for
Linxira OS.

Maintainer recovery, workstation rebuild, and release handoff instructions are
in [`docs/MAINTAINER_HANDOFF.md`](docs/MAINTAINER_HANDOFF.md).

## Repository layout

- `packages/`: one pinned PKGBUILD per Linxira-owned package
- `scripts/check-boundaries.sh`: rejects accidental replacement of upstream
  CachyOS packages and tool identities
- `.github/workflows/packages.yml`: isolated Arch container build, signing,
  `repo-add`, and GitHub Pages deployment

## Trust model

Every source package is pinned to a Git commit. Each CI matrix job starts from
a fresh official `archlinux:base-devel` image and runs a clean `makepkg` build.
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

## Package Installer

Once `[linxira]` is enabled, CachyOS Package Installer can discover Linxira
packages through normal pacman repository search. Linxira packages are not
added to CachyOS's curated Popular Apps list.
