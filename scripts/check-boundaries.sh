#!/usr/bin/env bash
set -euo pipefail

if grep -R -n -E "(provides|conflicts|replaces)=\([^)]*cachyos-hooks" packages; then
  echo "linxira-hooks must coexist with cachyos-hooks" >&2
  exit 1
fi

if grep -R -n -E "(provides|conflicts|replaces)=\([^)]*cachyos-hello" packages; then
  echo "Linxira must not replace CachyOS Hello" >&2
  exit 1
fi

if grep -R -n -E "Linxira (Package Installer|Kernel Manager)" packages; then
  echo "Upstream CachyOS tool identities must not be renamed" >&2
  exit 1
fi

if [[ -f packages/shelly/PKGBUILD ]]; then
  if grep -n -E 'CachyOS|cachyos|repo\.seafoam-labs\.org|aur\.archlinux\.org' packages/shelly/PKGBUILD; then
    echo "shelly must build from its pinned upstream source without CachyOS, AUR, or Seafoam repository inputs" >&2
    exit 1
  fi

  if grep -n -E '^\+.*(RunPrivilegedSystemCommandAsync|RemoveDbLockAsync|rm_db_lock_button|DownloadAndUnpackIcons)' \
    packages/shelly/linxira-safety-policy.patch; then
    echo "shelly must not restore disabled unsafe or automatic-download paths" >&2
    exit 1
  fi
fi

if [[ -f packages/calamares/PKGBUILD ]]; then
  if grep -n -E 'CachyOS|cachyos' packages/calamares/PKGBUILD; then
    echo "calamares must build from the pinned official upstream release" >&2
    exit 1
  fi
  grep -q 'releases/download/v${pkgver}/calamares-${pkgver}.tar.gz' packages/calamares/PKGBUILD
  grep -q "5547f80db067dea923ae693ba6bb88eb2b2eeac1da3ebec42fce453e31c290c0" \
    packages/calamares/PKGBUILD
  grep -q "0001-initcpiocfg-drop-obsolete-crc32c-intel.patch" packages/calamares/PKGBUILD
  grep -q "0231ff9d671cc590f96b863c69c341a1fca45f260ba79ed246b8a5b95fe0859d" \
    packages/calamares/PKGBUILD
  grep -q "0002-add-linxira-software-viewmodule.patch" packages/calamares/PKGBUILD
  grep -q "37a91daaacd58b1088099d0a8180232f00dea705670cbbcc8d9a6ae30582d6e4" \
    packages/calamares/PKGBUILD
fi

if [[ -f packages/linxira-welcome/PKGBUILD ]]; then
  if grep -n -E 'CachyOS|cachyos|shell=True|bash -c|sudo|pkexec' packages/linxira-welcome/PKGBUILD; then
    echo "linxira-welcome must remain independent and unprivileged" >&2
    exit 1
  fi
  grep -q '7394a21a53eecfc5df7fd04398b6c0500a5fa630' packages/linxira-welcome/PKGBUILD
fi

if [[ -f packages/linxira-update/PKGBUILD ]]; then
  grep -q '2d281c909331dc5c7884be1765bd75059ce96836' packages/linxira-update/PKGBUILD
  grep -q 'c7dab0270da60403ab2bd24acd8c9a27568378e7a436b89fe56a0143a282cf23' \
    packages/linxira-update/PKGBUILD
  grep -q "conflicts=('arch-update' 'cachy-update')" packages/linxira-update/PKGBUILD
  if grep -q '^replaces=' packages/linxira-update/PKGBUILD; then
    echo "linxira-update must not silently replace an installed updater" >&2
    exit 1
  fi
fi

if [[ -f packages/linxira-catalog/PKGBUILD ]]; then
  grep -q 'b8daa530214956e6723ffa71dfe8f8aac716e90c' packages/linxira-catalog/PKGBUILD
fi

grep -q 'a8134b4585e584fb596fc93641b77140481f0994' packages/linxira-components/PKGBUILD
grep -q '923347715d21f8fd67fb80f156da55e8dbf3d84c' packages/linxira-completion-agent/PKGBUILD
grep -q '5dfa4d9cd2d24df2df8eb67f4ad3675a0f8bc55e38b6e9eda0ee424eb06c8e37' \
  packages/linxira-completion-agent/PKGBUILD
grep -q "depends=.*'linxira-catalog'.*'linxira-components'" packages/linxira-completion-agent/PKGBUILD
grep -q '5d78caaafa7e79d6e132f6071fc2aa59cae83bd0' packages/linxira-config-hub/PKGBUILD
grep -q '374957b6a4bbe4b4a39dbab18789982fca1f097e' packages/linxira-component-manager/PKGBUILD
grep -q '9569e94634050a7ddc7c439b07595ddf5037a81e' packages/linxira-gaming-manager/PKGBUILD
grep -q 'afc3e03c7df79af893c4d64fd2320476d6c731551557e74dd24157b2f717632d' \
  packages/linxira-gaming-manager/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-gaming-manager/PKGBUILD; then
  echo "linxira-gaming-manager must remain user-scoped" >&2
  exit 1
fi
grep -q '5a6a7666e517e7c736e9892722b07204fb4a9871' packages/linxira-package-center/PKGBUILD

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
