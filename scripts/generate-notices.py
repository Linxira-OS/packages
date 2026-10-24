#!/usr/bin/env python3
"""在镜像 rootfs 里生成发布级许可证据（GPL §6 源码提供 + 第三方声明）。

输入: 一个已装好的 Arch rootfs（pacstrap 产物或 archiso airootfs）。
输出（默认 <root>/usr/share/doc/linxira/）:
  THIRD-PARTY-NOTICES.md    人有人的清单: Linxira 自有包 + 修改过的上游 + 非自由组件
  SOURCE-OFFER              GPLv3 §6(d) 式书面 offer + 逐包源码地址
  license-manifest.json     机器可读: 每个已装包的 name/version/licenses/licensesDir/source

设计要点:
- 许可数据一律取 pacman 自己的 %LICENSE% 字段(即 PKGBUILD 的 license=), 不另维护表;
- 源码地址只对 Linxira 自有包给出(GitHub 仓 + tag); Arch 包指向 Arch 官方包页;
- 不判断"是否合规", 只如实导出证据; 缺 /usr/share/licenses/<pkg> 的包会列出来(
  这是 CI/发布门应该看的信号)。
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

LINXIRA_REPOS = {
    # 包名 -> (仓库, 说明)
    "linxira-artwork": ("linxira-artwork", "品牌资产, custom:Linxira-Brand"),
    "linxira-catalog": ("linxira-catalog", "应用/组件目录"),
    "linxira-components": ("linxira-components", "系统事务引擎"),
    "linxira-component-manager": ("linxira-component-manager", "运行时安装器"),
    "linxira-config-hub": ("linxira-config-hub", "配置中心"),
    "linxira-crash-watch": ("linxira-crash-watch", "崩溃监视"),
    "linxira-completion-agent": ("linxira-completion-agent", "补全代理"),
    "linxira-gaming-manager": ("linxira-gaming-manager", "游戏管理"),
    "linxira-hardware-driver-manager": ("linxira-hardware-driver-manager", "硬件驱动管理"),
    "linxira-hwd-detector": ("linxira-hwd-detector", "硬件检测(fork: CachyOS/chwd, GPL-3.0-only)"),
    "linxira-kernel-manager": ("linxira-kernel-manager", "内核管理"),
    "linxira-package-center": ("linxira-package-center", "软件中心"),
    "linxira-recovery-diagnostics": ("linxira-recovery-diagnostics", "恢复诊断"),
    "linxira-update": ("linxira-update", "系统更新(派生: Antiz96/arch-Update, GPL-3.0-or-later)"),
    "linxira-welcome": ("linxira-welcome", "欢迎页"),
    "linxira-wiki": ("linxira-wiki", "离线 Wiki"),
    "linxira-hooks": ("linxira-hooks", "pacman hooks"),
    "linxira-keyring": ("linxira-keyring", "签名密钥环"),
    "linxira-bio-sdk": ("linxira-bio-sdk", "生物信息 SDK (AGPL-3.0-or-later)"),
    "calamares": ("linxira-calamares", "安装器(多许可, 见包内 LICENSES/)"),
    "shelly": ("", "上游 Seafoam-Labs/Shelly-ALPM 重打包 + 本地补丁"),
}

NON_FREE = {
    "linux-firmware": "固件二进制, 各自许可(多数允许再分发, 部分限制)",
    "unrar": "非自由解压工具, 仅允许免费使用/再分发原文",
    "libdvdcss": "CSS 解密库, 分发受当地法律限制",
    "nvidia": "专有驱动",
    "nvidia-utils": "专有驱动用户态",
}


def parse_desc(path: pathlib.Path) -> dict[str, list[str]]:
    fields: dict[str, list[str]] = {}
    key = None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("%") and line.endswith("%"):
            key = line.strip("%")
            fields[key] = []
        elif key is not None and line:
            fields[key].append(line)
    return fields


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--out", type=pathlib.Path, default=None)
    parser.add_argument("--version", default="")
    args = parser.parse_args()

    root = args.root.resolve()
    local = root / "var/lib/pacman/local"
    if not local.is_dir():
        print(f"错误: {local} 不存在(不是已安装的 rootfs?)", file=sys.stderr)
        return 1

    packages = []
    for desc in sorted(local.glob("*/desc")):
        fields = parse_desc(desc)
        name = (fields.get("NAME") or [desc.parent.name])[0]
        packages.append(
            {
                "name": name,
                "version": (fields.get("VERSION") or [""])[0],
                "licenses": fields.get("LICENSE") or [],
                "repo": LINXIRA_REPOS.get(name, ("", ""))[0],
                "note": LINXIRA_REPOS.get(name, ("", ""))[1],
                "licensesDir": f"/usr/share/licenses/{name}/"
                if (root / "usr/share/licenses" / name).is_dir()
                else "",
                "builtBy": "linxira" if name in LINXIRA_REPOS else "arch",
            }
        )

    linxira = [p for p in packages if p["builtBy"] == "linxira"]
    missing_dirs = [p["name"] for p in linxira if not p["licensesDir"]]
    non_free = [p for p in packages if p["name"] in NON_FREE]
    version = args.version or (root / "etc/linxira-release").read_text().strip() if (root / "etc/linxira-release").exists() else ""

    out = args.out or root / "usr/share/doc/linxira"
    out.mkdir(parents=True, exist_ok=True)

    manifest = {
        "schemaVersion": "org.linxira.license-manifest.v1",
        "imageVersion": version,
        "generatedFrom": str(root),
        "packages": packages,
    }
    (out / "license-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    lines = [
        "# Third-Party Notices",
        "",
        f"本文件由构建自动生成（linxira-packages/scripts/generate-notices.py），镜像版本: `{version or 'unknown'}`。",
        "机器可读版本见同目录 `license-manifest.json`。",
        "",
        "## Linxira OS 自有组件",
        "",
        "| 包 | 版本 | 许可 | 源码 | 说明 |",
        "|---|---|---|---|---|",
    ]
    for p in sorted(linxira, key=lambda item: item["name"]):
        repo = p["repo"]
        source = f"https://github.com/Linxira-OS/{repo}" if repo else "见包内说明"
        lines.append(
            f"| `{p['name']}` | {p['version']} | {', '.join(p['licenses']) or '见包内'} | {source} | {p['note']} |"
        )
    lines += [
        "",
        "## 修改过的上游项目",
        "",
        "- **Calamares**（安装器）：在本仓库有补丁，源码与补丁见 `Linxira-OS/packages/packages/calamares`；"
        "上游许可见 `/usr/share/licenses/calamares/LICENSES/`。",
        "- **Shelly**（软件中心）：上游 `Seafoam-Labs/Shelly-ALPM` GPL-3.0-only，本地补丁见包内 "
        "`/usr/share/doc/shelly/UPSTREAM.md`。",
        "- **Arch-Update**（`linxira-update`）：GPL-3.0-or-later，改动清单见仓库 `UPSTREAM.md`。",
        "- **CachyOS/chwd**（`linxira-hwd-detector`）：GPL-3.0-only，保留上游版权，见仓库 `UPSTREAM.md`。",
        "",
        "## Arch Linux 基础系统",
        "",
        "其余上游包（内核 GPL-2.0-only、systemd LGPL-2.1-or-later、KDE GPL/LGPL、Firefox MPL-2.0 等）"
        "的许可文本位于各包的 `/usr/share/licenses/<包名>/`，源码见 Arch Linux 官方包页 "
        "(https://archlinux.org/packages/)。完整许可列表见 `license-manifest.json`。",
        "",
        "## 非自由/受限组件",
        "",
    ]
    if non_free:
        lines += [f"- `{p['name']}` — {NON_FREE[p['name']]}" for p in non_free]
    else:
        lines.append("- 本镜像未包含已知非自由组件。")
    lines += [
        "",
        "## 缺失许可文本的 Linxira 包",
        "",
    ]
    if missing_dirs:
        lines += [f"- `{name}`（未安装 /usr/share/licenses/{name}/）" for name in missing_dirs]
    else:
        lines.append("- 无（每个 Linxira 包都带有 `/usr/share/licenses/<包名>/`）。")
    (out / "THIRD-PARTY-NOTICES.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    offer = f"""SOURCE OFFER — Linxira OS {version or ''}

本镜像包含 GPL/AGPL/LGPL 覆盖的二进制（例如 Calamares GPL-3.0-or-later、Shelly
GPL-3.0-only、linxira-update GPL-3.0-or-later、linxira-hooks GPL-3.0-or-later、
linxira-bio-sdk AGPL-3.0-or-later、linxira-hwd-detector GPL-3.0-only）。按相应许可
（GPLv3 §6 / AGPLv3 §13 / LGPLv3 §4）要求，提供完整对应的源码：

- Linxira 自有/派生组件的源码: 各仓库 https://github.com/Linxira-OS/<repo>
  （具体仓库与许可见同目录 THIRD-PARTY-NOTICES.md 与 license-manifest.json，
  构建使用精确的 tag/commit，见仓库历史）。
- 修改过的上游组件: Calamares 补丁与打包脚本见 Linxira-OS/packages；
  Shelly 补丁见 /usr/share/doc/shelly/UPSTREAM.md。
- Arch Linux 基础包源码: 见 https://archlinux.org/packages/ 对应版本，或
  https://archive.archlinux.org/ 的源码包/构建清单。
- 若需要书面获取方式（GPLv3 §6(d)），请联系: admin@linxira.org
  （请在信中注明镜像版本与本文件路径）。

本文件与二进制一起分发；移除本文件不改变上述许可义务。
"""
    (out / "SOURCE-OFFER").write_text(offer, encoding="utf-8")

    print(f"已写入 {out}: THIRD-PARTY-NOTICES.md / SOURCE-OFFER / license-manifest.json")
    print(f"  包总数 {len(packages)} | Linxira {len(linxira)} | 缺许可目录 {len(missing_dirs)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
