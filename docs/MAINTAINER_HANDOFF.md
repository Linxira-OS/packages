# Linxira OS Maintainer Handoff

This document is the recovery point for rebuilding the maintainer workstation,
restoring package signing, and resuming ISO or repository work. It intentionally
contains no private keys, passwords, tokens, SSH keys, or signing secrets.

## Current repositories

| Purpose | Repository | Known-good revision |
|---|---|---|
| Package definitions and Pages publishing | https://github.com/Linxira-OS/packages | `main` |
| Direct-Arch ISO profile | https://github.com/Linxira-OS/linxira-iso-direct | `e0f8697` |
| Linxira Welcome | https://github.com/Linxira-OS/linxira-welcome | `fe2aebdb32520da752834a3dc3bdf195b530fc14` |
| Reviewed catalog | https://github.com/Linxira-OS/linxira-catalog | `26eee173123602b1a6244d5be8640c331bf030dd` |
| Canonical artwork | https://github.com/Linxira-OS/linxira-artwork | `614dfb33e4aec9fa96adff28a8fa077cad8a8901` |
| Linxira pacman hooks | https://github.com/Linxira-OS/linxira-hooks | `25355105174646260fdb464cbdbe526055c825ae` |

The package CI is known good at:

https://github.com/Linxira-OS/packages/actions/runs/29335712348

It builds Calamares, Shelly, Linxira artwork, catalog, hooks, and Welcome in
fresh official Arch containers. The publish job remains disabled until signing
secrets and `linxira-keyring` are ready.

## Signing identity

Identity:

```text
Linxira OS Package Signing <admin@linxira.org>
```

Primary certification key:

```text
40F6 E8F6 863C AF88 0D92  3DB6 DA68 2900 7D77 0436
Expires: 2036-07-11
```

Package signing subkey:

```text
1110 38D9 5862 7BDC AC00  BEF9 C79B 1927 93F5 6DC6
Expires: 2028-07-13
```

The primary key is certification-only. Do not upload its private material to
GitHub. GitHub Actions must receive only a dedicated export of the signing
subkey.

## Backup gate

Do not reinstall the maintainer workstation until all of these are true:

1. The encrypted key archive has been copied to at least two USB drives.
2. A third encrypted copy exists on the maintainer NAS.
3. At least one external copy has been decrypted and its archive inspected.
4. The archive password is stored separately from the archive.
5. The primary fingerprint above has been recorded outside the workstation.

The expected encrypted archive filename is:

```text
linxira-key-backup-20260714.tar.gpg
```

Expected SHA-256:

```text
D3D497BDFE646DB155EF141957BA84E41F7F1866E463DDFD059BAB1A6B4830ED
```

The archive contains the protected primary-key backup, protected signing-subkey
backup, public key, revocation certificate, fingerprint, and recovery notes.

## Workstation rebuild

Install these tools after Windows is available again:

- Git
- GitHub CLI
- Gpg4win
- OpenSSH client
- ImageMagick for boot and branding asset generation

Clone the maintained repositories under one workspace root. Authenticate
GitHub CLI, restore the SSH key used for the external ISO builder, and verify
all remote URLs before pushing.

Restore the signing key only after verifying the encrypted archive hash and
the primary fingerprint. Import the full secret backup on a trusted machine;
do not import it into CI. A signing-subkey-only export is used for repository
automation.

## Dual-boot storage safety

The Windows and Linux installations may modify only the designated primary
system disk. Work and backup disks must not be repartitioned or formatted.

Before installation:

1. Complete the signing-key backup gate above.
2. Back up the workspace and any unpushed changes.
3. Record the model, capacity, and partition layout of every disk.
4. Physically disconnect non-system work disks when practical. Otherwise,
   disable them in firmware before installing Windows or Linux.
5. Keep verified backups of any BitLocker recovery keys.

Install Windows on the primary disk first and leave unallocated space for
Linux. Install Linux only into that unallocated space. Reuse the primary disk's
EFI System Partition without formatting it. Reconnect NTFS work disks only
after both systems boot successfully.

Do not identify an installation target by drive letter alone. Drive letters
can change in setup environments; confirm the physical disk model and capacity.

## Package repository operation

Package definitions live under `packages/`. A normal push or pull request runs
boundary checks and package builds but never publishes.

Signed publication requires these GitHub repository secrets:

- `LINXIRA_GPG_PRIVATE_KEY`
- `LINXIRA_GPG_FINGERPRINT`

After `linxira-keyring` is available and the CI signing-subkey export has been
configured, manually run `Build and publish packages` with `publish` enabled.
The intended repository URL is:

```ini
[linxira]
SigLevel = Required DatabaseOptional
Server = https://linxira-os.github.io/packages/$arch
```

Do not add this repository to an ISO before the public keyring package is
installed and the first signed Pages deployment has been independently tested.

## ISO baseline

The Direct-Arch RC7 candidate produced on 2026-07-18 is:

```text
linxira-2026.07.18-direct-arch-welcome-rc7-x86_64.iso
SHA-256: 02103E30BE4FBAC0F4E7296B58A30C56ED9EC47134116A38F3269DDE57CBD27F
```

It uses official Arch repositories plus locally built upstream Calamares,
Shelly, and Linxira artwork packages. Static checks, 22 source tests, SquashFS
self-check, and QEMU BIOS/UEFI menu boots passed. Scale L appears in both boot
menus. Full RC7 Plasma, Welcome, language switching, disk installation, first
boot, and recovery acceptance remain outstanding.

## Resume order

1. Complete RC7 Plasma, Welcome, language, installation, and recovery tests.
2. Build `linxira-keyring` from the public key.
3. Prepare a signing-subkey-only CI export and configure repository secrets.
4. Publish and verify the first signed GitHub Pages repository.
5. Replace remaining ISO source overlays with signed Linxira packages.
6. Rebuild and test the signed live and installed-system workflows.
