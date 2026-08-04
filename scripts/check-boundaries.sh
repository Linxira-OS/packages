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
  grep -q "bd47459b58573a992da3f71c549fdac83a9210075076875c91351c12816c73e9" \
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
  grep -q '1bdf1afb9e7fd327b84bd0a118ff599d07864961' packages/linxira-welcome/PKGBUILD
  grep -q 'f0692e795a64a01ac9fd2536597828cefef492c5f36136109daab41d67baf9b4' packages/linxira-welcome/PKGBUILD
fi

if [[ -f packages/linxira-update/PKGBUILD ]]; then
  grep -q 'a4a1f949a707a9430ac7b8a719aa2ac3f0549e31' packages/linxira-update/PKGBUILD
  grep -q '9d93e84894d9a76add158ccba723734be0efc558f34e8c35666d552cf3936dee' \
    packages/linxira-update/PKGBUILD
  grep -q "conflicts=('arch-update' 'cachy-update')" packages/linxira-update/PKGBUILD
  if grep -q '^replaces=' packages/linxira-update/PKGBUILD; then
    echo "linxira-update must not silently replace an installed updater" >&2
    exit 1
  fi
fi

if [[ -f packages/linxira-catalog/PKGBUILD ]]; then
  grep -q 'b55075e33475816add7639a8dd470d9c3bf232dc' packages/linxira-catalog/PKGBUILD
  grep -q 'ff62c36f2f0189db7b7c3fb489f2096342c6438b555c90df7283f6f42b75a5f4' packages/linxira-catalog/PKGBUILD
fi

grep -q 'cfff5359b0fc0e66ec22ea9a91f2b69d17c7fdf9' packages/linxira-components/PKGBUILD
grep -q 'f8e0bfe95be79b0866a2572f3cbbdb57e563af2318afa3cf2c2dec6cca82b9e2' packages/linxira-components/PKGBUILD
grep -q 'scripts/linxira-components-service' packages/linxira-components/PKGBUILD
grep -q 'scripts/linxira-components-worker' packages/linxira-components/PKGBUILD
grep -q 'service/linxira-components.service' packages/linxira-components/PKGBUILD
grep -q 'service/linxira-components-worker@.service' packages/linxira-components/PKGBUILD
grep -q 'org.linxira.components.policy' packages/linxira-components/PKGBUILD
grep -q "'python-dbus'" packages/linxira-components/PKGBUILD
grep -q 'pkgver=0.7.0' packages/linxira-components/PKGBUILD
grep -q "'pyalpm'" packages/linxira-components/PKGBUILD
grep -q '394d2a90abbebc1fec618dd0ca8844167ad74e94' packages/linxira-completion-agent/PKGBUILD
grep -q '0aa0e5669db982337d08202cb0aa583700522a56afbb48bee915580fe332ea68' \
  packages/linxira-completion-agent/PKGBUILD
grep -q "depends=.*'linxira-catalog'.*'linxira-components'" packages/linxira-completion-agent/PKGBUILD
grep -q '2ba853f094896e9500232c681c4a3ddb43c38448' packages/linxira-chwd-detector/PKGBUILD
grep -q '50e6b7324bc4fa065be79f27d7e0da5d4ba5e7b98537329d3f0c7e42dbbd90c2' \
  packages/linxira-chwd-detector/PKGBUILD
grep -q '27698ad385849930ac70e67cb1d03ce715a142fb' packages/linxira-hardware-driver-manager/PKGBUILD
grep -q '338f36b8c2d17e8e7321d9de45b5f354b3a0090f89fb562da8a9a518fb120f5d' \
  packages/linxira-hardware-driver-manager/PKGBUILD
grep -q "depends=.*'linxira-chwd-detector'" packages/linxira-hardware-driver-manager/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-hardware-driver-manager/PKGBUILD; then
  echo "linxira-hardware-driver-manager MVP must remain report-and-plan only" >&2
  exit 1
fi
grep -q 'bdb65855c2043f7ae4983b2c898b86d542fb77ce' packages/linxira-kernel-manager/PKGBUILD
grep -q 'ffc39d90b17bc0f6cceae71d882b9399609375702722e2fc63b6983b1b4e46e4' \
  packages/linxira-kernel-manager/PKGBUILD
grep -q 'dba92f7f215ea304e40d6fda931bc9cf436617df' packages/linxira-recovery-diagnostics/PKGBUILD
grep -q '03ca7b471d86bef7c7a29cdb189ba62ec8dd74b0d0daef4c70737c83802b6eed' \
  packages/linxira-recovery-diagnostics/PKGBUILD
grep -q "'linxira-components>=0.4.0'" packages/linxira-recovery-diagnostics/PKGBUILD
if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-kernel-manager/PKGBUILD packages/linxira-recovery-diagnostics/PKGBUILD; then
  echo "kernel and recovery clients must not package their own privileged service" >&2
  exit 1
fi
grep -q '7450ed5937fa556c1ba853f5ffa094e0dd9877ee' packages/linxira-config-hub/PKGBUILD
grep -q '986f54e4e37d1fa5f76a26a7a53e7a12f19f100ac604830c16d6ae30d4238b1e' packages/linxira-config-hub/PKGBUILD
grep -q '4accd7877093c94ef29b34a0a91ddb4849f262c8' packages/linxira-component-manager/PKGBUILD
grep -q '208d2aefb6e82bfbab24665069f1efc0bffbc72d' packages/linxira-gaming-manager/PKGBUILD
grep -q '9bbacc33079d67779547ede0ae1af7c35c1be277df78cb661233a53f12ddb69e' \
  packages/linxira-gaming-manager/PKGBUILD
if grep -E -n "install.*systemd/system|install.*polkit" \
  packages/linxira-gaming-manager/PKGBUILD; then
  echo "linxira-gaming-manager must remain user-scoped" >&2
  exit 1
fi
grep -q '9364644a9009fc7f09a67c955143c9dd3bb79cfc' packages/linxira-package-center/PKGBUILD

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
