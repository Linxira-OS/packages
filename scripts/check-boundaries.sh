#!/usr/bin/env bash
set -euo pipefail

# pin 校验失败时不能静默退出：打印失败行号，否则 CI 日志里只有 exit 1 无从排障
trap 'echo "[boundaries] 校验失败于第 $LINENO 行（pin 过期或出现禁止模式），最后校验的命令见上方 bash -x 输出" >&2' ERR

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
  grep -q "302c6593bda4b220e8b6997aeb36f8d852c68c7b4e86cdc4c4531b1812938454" \
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
  grep -q '6fe04d1d8f012edce95bbad1d644e0dbaf3b3ed9' packages/linxira-welcome/PKGBUILD
  grep -q 'e32ba1902973532484e5032001d9f18d6f7d7b57961232fd314629670288aafd' packages/linxira-welcome/PKGBUILD
fi

if [[ -f packages/linxira-update/PKGBUILD ]]; then
  grep -q 'c51f0e35852f79a77539b27503f15150d66c62a1' packages/linxira-update/PKGBUILD
  grep -q '6d837e8767202b8fa1513f00eb59b7387542c6fece4f47ba129caa4f31d4b9f5' \
    packages/linxira-update/PKGBUILD
  grep -q "conflicts=('arch-update' 'cachy-update')" packages/linxira-update/PKGBUILD
  if grep -q '^replaces=' packages/linxira-update/PKGBUILD; then
    echo "linxira-update must not silently replace an installed updater" >&2
    exit 1
  fi
fi

if [[ -f packages/linxira-catalog/PKGBUILD ]]; then
  grep -q '90db15bdeb98740a0004ecf3541da532c83db940' packages/linxira-catalog/PKGBUILD
  grep -q 'acd7dd96bfbfeed8182ef3c930bc7623e42a658e4d2aafb20a5d8091436d6f20' packages/linxira-catalog/PKGBUILD
fi

grep -q 'd07474fb8c286d706e1829abe01598b640832eaf' packages/linxira-components/PKGBUILD
grep -q 'e765241cf6405d13f28d0d21d2e53b195d925a0b5b7104258633e69f782046ce' packages/linxira-components/PKGBUILD
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
grep -q '1d5b5a611811d498e6e457e680e66b0d15f4fb84' packages/linxira-hwd-detector/PKGBUILD
grep -q 'ba1b7ad8878ca39c25dc3cd674cfa34aae9102126346133300b3408dad187ba3' \
  packages/linxira-hwd-detector/PKGBUILD
grep -q '82a0796d4dd1dac50c71a985081fd030e84163f2' packages/linxira-hardware-driver-manager/PKGBUILD
grep -q '060f0ab7d94b9ee92029dab363986518524326c29a50cd17abd56edaf4167739' \
  packages/linxira-hardware-driver-manager/PKGBUILD
grep -q "depends=.*'linxira-hwd-detector'" packages/linxira-hardware-driver-manager/PKGBUILD
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
grep -q 'c785a407493d40ec34d073a05c52ab4e2325f053' packages/linxira-config-hub/PKGBUILD
grep -q '72ec1c5f98337d8db72ab50852826489f4d74f23bd38d5c816aa2e33b32b2577' packages/linxira-config-hub/PKGBUILD
grep -q '1deed77b28af46bf2351d0de757ea216c6ce52ff' packages/linxira-component-manager/PKGBUILD
grep -q '72244435fccf888c0c9914731f0efff63b2baa36' packages/linxira-gaming-manager/PKGBUILD
grep -q 'a80a41fec6611af7f03b9aa9b5cd9a44fe0fbb40479e1be25d92d511ff4d192a' \
  packages/linxira-gaming-manager/PKGBUILD
if grep -E -n "install.*systemd/system|install.*polkit" \
  packages/linxira-gaming-manager/PKGBUILD; then
  echo "linxira-gaming-manager must remain user-scoped" >&2
  exit 1
fi
grep -q '2c1e53d47aef388fcfff295027f438ad119a552b' packages/linxira-package-center/PKGBUILD

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
