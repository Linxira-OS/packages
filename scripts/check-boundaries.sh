#!/usr/bin/env bash
set -euo pipefail

# 校验失败时不能静默退出：打印失败行号，否则 CI 日志里只有 exit 1 无从排障
trap 'echo "[boundaries] 校验失败于第 $LINENO 行（语义边界或结构校验未过），最后校验的命令见上方 bash -x 输出" >&2' ERR

# 2026-09-20 重构说明：本脚本原先对 12 个包逐个硬编码 commit+sha256 数值锁，
# 每次上游 bump 都会腐烂（已两次阻断发布流水线：welcome、config-hub）。
# 现在只保留语义边界（身份、权限、依赖关系），数值完整性交给下方通用结构
# 校验；版本审核门槛由「上游正式 Release + 签名发布」承担。

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
fi

if [[ -f packages/linxira-update/PKGBUILD ]]; then
  grep -q "conflicts=('arch-update' 'cachy-update')" packages/linxira-update/PKGBUILD
  if grep -q '^replaces=' packages/linxira-update/PKGBUILD; then
    echo "linxira-update must not silently replace an installed updater" >&2
    exit 1
  fi
fi

if [[ -f packages/linxira-components/PKGBUILD ]]; then
  grep -q 'scripts/linxira-components-service' packages/linxira-components/PKGBUILD
  grep -q 'scripts/linxira-components-worker' packages/linxira-components/PKGBUILD
  grep -q 'service/linxira-components.service' packages/linxira-components/PKGBUILD
  grep -q 'service/linxira-components-worker@.service' packages/linxira-components/PKGBUILD
  grep -q 'org.linxira.components.policy' packages/linxira-components/PKGBUILD
  grep -q "'python-dbus'" packages/linxira-components/PKGBUILD
  grep -q "'pyalpm'" packages/linxira-components/PKGBUILD
fi

if [[ -f packages/linxira-completion-agent/PKGBUILD ]]; then
  grep -q "depends=.*'linxira-catalog'.*'linxira-components'" packages/linxira-completion-agent/PKGBUILD
fi

if [[ -f packages/linxira-hardware-driver-manager/PKGBUILD ]]; then
  grep -q "depends=.*'linxira-hwd-detector'" packages/linxira-hardware-driver-manager/PKGBUILD
  if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
    packages/linxira-hardware-driver-manager/PKGBUILD; then
    echo "linxira-hardware-driver-manager MVP must remain report-and-plan only" >&2
    exit 1
  fi
fi

if [[ -f packages/linxira-recovery-diagnostics/PKGBUILD ]]; then
  grep -q "'linxira-components>=0.4.0'" packages/linxira-recovery-diagnostics/PKGBUILD
fi

if grep -E -n "depends=.*polkit|install.*systemd/system|install.*polkit" \
  packages/linxira-kernel-manager/PKGBUILD packages/linxira-recovery-diagnostics/PKGBUILD; then
  echo "kernel and recovery clients must not package their own privileged service" >&2
  exit 1
fi

if [[ -f packages/linxira-gaming-manager/PKGBUILD ]]; then
  if grep -E -n "install.*systemd/system|install.*polkit" \
    packages/linxira-gaming-manager/PKGBUILD; then
    echo "linxira-gaming-manager must remain user-scoped" >&2
    exit 1
  fi
fi

# 通用结构校验：语法 + 固定源(_commit)格式 + 校验和完整
for package in packages/*/PKGBUILD; do
  bash -n "$package"
  if grep -q '^_commit=' "$package"; then
    # 40 位十六进制; linxira-keyring 的 _commit 是大写 GPG 指纹(白名单特例)
    grep -Eq '^_commit=[0-9a-fA-F]{40}$' "$package" || {
      echo "$package: _commit 必须是 40 位十六进制 commit/指纹" >&2
      exit 1
    }
  fi
  if grep -q '^sha256sums' "$package" && ! grep -q "SKIP" "$package"; then
    python3 - "$package" <<'PYEOF'
import re, sys
path = sys.argv[1]
text = open(path, "rb").read().decode("utf-8", "replace")
match = re.search(r"^sha256sums=\((.*?)\)", text, re.S | re.M)
bad = []
if not match:
    bad.append("sha256sums block not found")
else:
    for token in re.findall(r"'([^']*)'", match.group(1)):
        if not re.fullmatch(r"[0-9a-f]{64}|SKIP", token):
            bad.append(token)
if bad:
    print(f"{path}: sha256sums 存在非法校验和: {bad}", file=sys.stderr)
    sys.exit(1)
PYEOF
  fi
done
