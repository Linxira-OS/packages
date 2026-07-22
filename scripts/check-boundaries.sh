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
  grep -q "299742d4f9519dc4128f4e7aef65bbe4a1cd964ddf18992716fc87e116367027" \
    packages/calamares/PKGBUILD
  grep -q 'install(FILES linxirasoftware.conf' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
  grep -q 'load: "libcalamares_viewmodule_linxirasoftware.so"' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
  grep -q 'QStringLiteral( "exclusive" )' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
  grep -q 'org.linxira.installer-selection.v1' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
  grep -q 'QStringLiteral( "desktops" )' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
  grep -q 'QStringLiteral( "bounded" )' \
    packages/calamares/0002-add-linxira-software-viewmodule.patch
fi

if [[ -f packages/linxira-welcome/PKGBUILD ]]; then
  if grep -n -E 'CachyOS|cachyos|shell=True|bash -c|sudo|pkexec' packages/linxira-welcome/PKGBUILD; then
    echo "linxira-welcome must remain independent and unprivileged" >&2
    exit 1
  fi
  grep -q '7c0d1128ae7d6d5947bdc2cb246ceab0f6052b4e' packages/linxira-welcome/PKGBUILD
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
  grep -q 'ce30201c8913ef92022ecd4ecd44c7bad31fd9c8' packages/linxira-catalog/PKGBUILD
fi

grep -q 'fab1262fcdfcfd141e9644d4d42db0c4b2ecb1e0' packages/linxira-components/PKGBUILD
grep -q 'b986a0972d8ddecb11489c92aa1efac47650a47b' packages/linxira-completion-agent/PKGBUILD
grep -q 'bd8447ed5ec6445744c5a7fdfd5ac9ff1c7a568fcad56ad9c468d66e75301953' \
  packages/linxira-completion-agent/PKGBUILD
grep -q "depends=.*'linxira-catalog'.*'linxira-components'" packages/linxira-completion-agent/PKGBUILD
grep -q '2ba853f094896e9500232c681c4a3ddb43c38448' packages/linxira-chwd-detector/PKGBUILD
grep -q '50e6b7324bc4fa065be79f27d7e0da5d4ba5e7b98537329d3f0c7e42dbbd90c2' \
  packages/linxira-chwd-detector/PKGBUILD
grep -q '6755adee9dfaeed06f8dedd56707bddfeff44e92' packages/linxira-hardware-driver-manager/PKGBUILD
grep -q '0fe9934a7565245b07d371b463d9be64a40173e60a3cbc6bf3f545c7ad477b84' \
  packages/linxira-hardware-driver-manager/PKGBUILD
grep -q "depends=.*'linxira-chwd-detector'" packages/linxira-hardware-driver-manager/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-hardware-driver-manager/PKGBUILD; then
  echo "linxira-hardware-driver-manager MVP must remain report-and-plan only" >&2
  exit 1
fi
grep -q '40b27d0e733bbfb8edae83151ce3059e204c0967' packages/linxira-kernel-manager/PKGBUILD
grep -q 'aa6c60b9608cea69ae162e0eaf7b7cf38b7cf6eee9ec943b7cabaf3e7795f3d8' \
  packages/linxira-kernel-manager/PKGBUILD
grep -q '2c05f516fa25840d89d81c15923d82771b86ddc8' packages/linxira-recovery-diagnostics/PKGBUILD
grep -q '38a6408340dcd79fad542e1b385a8cdfe05603ddc2b81139b5e1abece16c7b14' \
  packages/linxira-recovery-diagnostics/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-kernel-manager/PKGBUILD packages/linxira-recovery-diagnostics/PKGBUILD; then
  echo "kernel and recovery MVP packages must remain report-and-plan only" >&2
  exit 1
fi
grep -q '5d78caaafa7e79d6e132f6071fc2aa59cae83bd0' packages/linxira-config-hub/PKGBUILD
grep -q 'a848d9c244e00eb526a83de5a6976a88e942c7bb' packages/linxira-component-manager/PKGBUILD
grep -q '38232a13ca8683bd12caee20abe990e661f08dd7' packages/linxira-gaming-manager/PKGBUILD
grep -q 'd443161d91e28d21dec0efe8f1b9d331d10ce7e8f2bb1df90d2712b18b355b13' \
  packages/linxira-gaming-manager/PKGBUILD
if grep -E -n "install.*systemd/system|install.*polkit" \
  packages/linxira-gaming-manager/PKGBUILD; then
  echo "linxira-gaming-manager must remain user-scoped" >&2
  exit 1
fi
grep -q 'f49c7790416ae2c7b1677b58f81205bd01c87944' packages/linxira-package-center/PKGBUILD

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
