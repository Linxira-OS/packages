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
  grep -q '35961740a8c568f17990471f9a1e3de28bd91ac2' packages/linxira-welcome/PKGBUILD
  grep -q '99213e0a367cd4c073c37abcb87f31d7c837248446b8453bf00a699f4815cc0b' packages/linxira-welcome/PKGBUILD
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
  grep -q '66aeb725b9bbbee9ac3c810c2e64c7c929863bf4' packages/linxira-catalog/PKGBUILD
  grep -q '427eb8df5bf80922028ce6a09d932660c38e5028f6cd50218cdc86daa4f2f11b' packages/linxira-catalog/PKGBUILD
fi

grep -q '9dcd29b7f4f68b43cddcbf692536a15581a66c14' packages/linxira-components/PKGBUILD
grep -q '5d7bd9c0e0bbe9b5f15dfd6ec35a1e6f4eb31f347f590e5cb3180239a788bfbb' packages/linxira-components/PKGBUILD
grep -q 'scripts/linxira-components-service' packages/linxira-components/PKGBUILD
grep -q 'scripts/linxira-components-worker' packages/linxira-components/PKGBUILD
grep -q 'service/linxira-components.service' packages/linxira-components/PKGBUILD
grep -q 'service/linxira-components-worker@.service' packages/linxira-components/PKGBUILD
grep -q 'org.linxira.components.policy' packages/linxira-components/PKGBUILD
grep -q "'python-dbus'" packages/linxira-components/PKGBUILD
grep -q 'pkgver=0.6.0' packages/linxira-components/PKGBUILD
grep -q "'pyalpm'" packages/linxira-components/PKGBUILD
grep -q 'b986a0972d8ddecb11489c92aa1efac47650a47b' packages/linxira-completion-agent/PKGBUILD
grep -q '2288eaa81c6d86ce161b975eda15858540cf1bfc0b6d0fb958559d6fd3aa6bc3' \
  packages/linxira-completion-agent/PKGBUILD
grep -q "depends=.*'linxira-catalog'.*'linxira-components'" packages/linxira-completion-agent/PKGBUILD
grep -q '2ba853f094896e9500232c681c4a3ddb43c38448' packages/linxira-chwd-detector/PKGBUILD
grep -q '50e6b7324bc4fa065be79f27d7e0da5d4ba5e7b98537329d3f0c7e42dbbd90c2' \
  packages/linxira-chwd-detector/PKGBUILD
grep -q '1cc3eb3040bea48a68b83e0b4f4ddfac32b510ff' packages/linxira-hardware-driver-manager/PKGBUILD
grep -q 'f5382ff2d1612545f83712876d34f9aa18ebde6c3603191c8963538f4d1f31f5' \
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
grep -q 'badc0f75e4b31453fa11376caf985c2314eb1792' packages/linxira-recovery-diagnostics/PKGBUILD
grep -q '31db718145af2c9b67019ec70f999c8c0ac0fc31154b36573afb604943dd6326' \
  packages/linxira-recovery-diagnostics/PKGBUILD
grep -q "'linxira-components>=0.4.0'" packages/linxira-recovery-diagnostics/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-kernel-manager/PKGBUILD packages/linxira-recovery-diagnostics/PKGBUILD; then
  echo "kernel and recovery clients must not package their own privileged service" >&2
  exit 1
fi
grep -q '7e679a522b8ce280469e7fcd05cce5a6adb283c8' packages/linxira-config-hub/PKGBUILD
grep -q '18e68d450d3c2305b1615a20a49e6ab476bad402a3404ae62f9e34474b55eaed' packages/linxira-config-hub/PKGBUILD
grep -q 'a848d9c244e00eb526a83de5a6976a88e942c7bb' packages/linxira-component-manager/PKGBUILD
grep -q 'b9d7edc7372312f5f2c5b15cf552474af6a5debe' packages/linxira-gaming-manager/PKGBUILD
grep -q '9048f6a7511c830ea8709c24dcace29fbc3b57e1ce2f7bd6034be8550a38008c' \
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
