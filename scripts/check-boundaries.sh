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
fi

if [[ -f packages/linxira-welcome/PKGBUILD ]]; then
  if grep -n -E 'CachyOS|cachyos|shell=True|bash -c|sudo|pkexec' packages/linxira-welcome/PKGBUILD; then
    echo "linxira-welcome must remain independent and unprivileged" >&2
    exit 1
  fi
  grep -q '10b705d40761b01ef569e5abf1362ddac4b2c94d' packages/linxira-welcome/PKGBUILD
fi

if [[ -f packages/linxira-catalog/PKGBUILD ]]; then
  grep -q '62b141f2454cd1ed985b1b4a58c5c350dc3104ba' packages/linxira-catalog/PKGBUILD
fi

grep -q '05ef463125fa8e935ad8dda555aebbce20bbb3bd' packages/linxira-components/PKGBUILD
grep -q 'c41dd4ce621fe1d18744b1df599c8fa528d3cdc6' packages/linxira-config-hub/PKGBUILD
grep -q 'b3a807ff0116e8a51f995169ba16a69495ba13da' packages/linxira-package-center/PKGBUILD

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
