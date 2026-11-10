#!/usr/bin/env python3
"""`scripts/sync-upstream.py` 的回归测试。

2026-10-14 事故: 上游 zeta v1.2.1 发布后, 当日 `auto-bump` 在 "Scan upstream releases"
阶段直接崩掉 —— `render_report()` 抛 `KeyError: 'new_pkgver'`。根因是 assets 模式分支
丢弃了 `bump_assets()` 的返回值(未把 new_pkgver/pkgrel 合入结果行), 而报告在有写入时
硬读 `new_pkgver`。整条链(含当日所有包)因此失败。

本测试锁定两条不变量:
1. `scan_one()` 在 assets 模式写入后, 结果行必须自带渲染所需的键;
2. `render_report()` 对任何状态/模式的行都不得抛异常。
"""
import importlib.util
import os
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
_SCRIPT = pathlib.Path(
    os.environ.get("SYNC_UPSTREAM_PY", str(ROOT / "scripts" / "sync-upstream.py"))
)
_spec = importlib.util.spec_from_file_location("sync_upstream", _SCRIPT)
mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mod)

ZETA_PKGBUILD = """\
# Maintainer: Linxira OS <admin@linxira.org>
pkgname=linxira-zeta-desktop-bin
pkgver=1.1.27
pkgrel=1
arch=('x86_64')
source=("zeta-desktop-${pkgver}-linux-x64.tar.gz::https://github.com/Linxira-OS/linxira-zeta/releases/download/v${pkgver}/zeta-desktop-${pkgver}-linux-x64.tar.gz")
sha256sums=('5ec8ab0150c803c444d57d43e437d02c5d92b48ee6eff9299e960b4547109c6d')

package() {
  install -d "$pkgdir/opt/zeta"
}
"""

CODELOAD_PKGBUILD = """\
pkgname=linxira-catalog
pkgver=3.2.8
pkgrel=1
_commit=db6cd53b9ef76adba9a9af4119deede114e074d3
source=("$pkgname-$_commit.tar.gz::https://codeload.github.com/Linxira-OS/$pkgname/tar.gz/$_commit")
sha256sums=('8669d683d4a8a8544a6b5c15c31f3b2ebb3cad36d9a87a7dee7af97d2fe70b6a')
"""

MULTI_ASSET_PKGBUILD = """\
pkgname=linxira-zeta-c-bin
pkgver=1.4.11
pkgrel=1
source=("zeta-cli-linux-x64::https://github.com/Linxira-OS/linxira-zeta/releases/download/v${pkgver}/zeta-cli-linux-x64"
"LICENSE::https://github.com/Linxira-OS/linxira-zeta/releases/download/v${pkgver}/LICENSE"
)
sha256sums=('d66d2d2f23f06817d4e37be21463c5e7afb602c1f17e87163ea6d674be508287'
'dc4eb64d767658a18fc64ea98344ac86365564196f61df33b76c5871fe3a844f'
)
"""

ZETA_BIN_SHA = "d66d2d2f23f06817d4e37be21463c5e7afb602c1f17e87163ea6d674be508287"
ZETA_LICENSE_SHA = "49cc81b4d6bbe6a25b7b5a5942759775e42cbf71d688fbaf08b5d06733236c32"


class FakeGitHub:
    """只实现 assets 模式用到的两个调用。"""

    def __init__(self, tag="v1.2.1", commit="a" * 40, sha="b" * 64, shas=None):
        self.tag, self.commit, self.sha = tag, commit, sha
        self.shas = shas
        self.calls = 0

    def latest_release(self, repo):
        self.calls += 1
        return (self.tag, self.commit)

    def release_asset_sha(self, repo, tag, asset_name):
        self.calls += 1
        if self.shas is not None:
            return self.shas.get(asset_name)
        return self.sha

    def tarball_sha256(self, repo, commit):
        self.calls += 1
        return self.sha


class ScanOneTests(unittest.TestCase):
    def test_assets_bump_row_is_renderable(self):
        """修复点: assets 模式写入后必须带上 new_pkgver/pkgrel, 且报告能渲染。"""
        with tempfile.TemporaryDirectory() as tmp:
            pkgbuild = pathlib.Path(tmp) / "PKGBUILD"
            pkgbuild.write_text(ZETA_PKGBUILD, encoding="utf-8")
            row = mod.scan_one(FakeGitHub(), "linxira-zeta-desktop-bin",
                               "Linxira-OS/linxira-zeta", pkgbuild, True, mode="assets")
            text = pkgbuild.read_text(encoding="utf-8")

        self.assertEqual("bump", row["status"])
        self.assertTrue(row["applied"])
        self.assertEqual("1.2.1", row["new_pkgver"])
        self.assertIn("pkgver=1.2.1", text)
        self.assertEqual("1", row["pkgrel"])
        # 修复前这里抛 KeyError: 'new_pkgver'
        report = mod.render_report([row])
        self.assertIn("`1.2.1`", report)
        self.assertIn("资产模式", report)

    def test_assets_dry_run_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            pkgbuild = pathlib.Path(tmp) / "PKGBUILD"
            pkgbuild.write_text(ZETA_PKGBUILD, encoding="utf-8")
            row = mod.scan_one(FakeGitHub(), "linxira-zeta-desktop-bin",
                               "Linxira-OS/linxira-zeta", pkgbuild, False, mode="assets")
            self.assertIn("pkgver=1.1.27", pkgbuild.read_text(encoding="utf-8"))

        self.assertEqual("bump", row["status"])
        self.assertFalse(row["applied"])
        self.assertIn("未写入", mod.render_report([row]))

    def test_codeload_bump_row_keeps_commit_note(self):
        with tempfile.TemporaryDirectory() as tmp:
            pkgbuild = pathlib.Path(tmp) / "PKGBUILD"
            pkgbuild.write_text(CODELOAD_PKGBUILD, encoding="utf-8")
            row = mod.scan_one(FakeGitHub(tag="v3.3.0"), "linxira-catalog",
                               "Linxira-OS/linxira-catalog", pkgbuild, True, mode="codeload")

        self.assertEqual("bump", row["status"])
        self.assertTrue(row["applied"])
        report = mod.render_report([row])
        self.assertIn("rel=1", report)
        self.assertIn("…", report)  # old_commit…new_commit


class AssetsChecksumTests(unittest.TestCase):
    """2026-11-06 事故: assets 模式只回填 sha256sums[0]，LICENSE 停在旧版本。

    zeta 1.4.11 换了 LICENSE 后 zeta-c-bin / zeta-ide 校验失败被静默跳过；
    另外 v1.4.10 的包资产被上游重传，而同版本旧逻辑直接报 ok，导致
    zeta-stack 构建失败。这里锁定两条不变量：
    1. 同一版本下校验和变化也要 bump（pkgrel +1）并回填每一条；
    2. 版本与全部校验和都一致时才是 ok，不写文件。
    """

    def test_assets_refreshes_every_checksum(self):
        shas = {"zeta-cli-linux-x64": ZETA_BIN_SHA, "LICENSE": ZETA_LICENSE_SHA}
        with tempfile.TemporaryDirectory() as tmp:
            pkgbuild = pathlib.Path(tmp) / "PKGBUILD"
            pkgbuild.write_text(MULTI_ASSET_PKGBUILD, encoding="utf-8")
            row = mod.scan_one(FakeGitHub(tag="v1.4.11", shas=shas),
                               "linxira-zeta-c-bin", "Linxira-OS/linxira-zeta",
                               pkgbuild, True, mode="assets")
            text = pkgbuild.read_text(encoding="utf-8")

        self.assertEqual("bump", row["status"])
        self.assertEqual("1.4.11", row["new_pkgver"])
        self.assertEqual("2", row["pkgrel"])
        self.assertIn(ZETA_BIN_SHA, text)
        self.assertIn(ZETA_LICENSE_SHA, text)
        self.assertNotIn("dc4eb64d767658a18fc64ea98344ac86365564196f61df33b76c5871fe3a844f", text)

    def test_assets_same_version_same_checksums_is_ok(self):
        current = {"zeta-cli-linux-x64": ZETA_BIN_SHA, "LICENSE":
                   "dc4eb64d767658a18fc64ea98344ac86365564196f61df33b76c5871fe3a844f"}
        with tempfile.TemporaryDirectory() as tmp:
            pkgbuild = pathlib.Path(tmp) / "PKGBUILD"
            pkgbuild.write_text(MULTI_ASSET_PKGBUILD, encoding="utf-8")
            row = mod.scan_one(FakeGitHub(tag="v1.4.11", shas=current),
                               "linxira-zeta-c-bin", "Linxira-OS/linxira-zeta",
                               pkgbuild, True, mode="assets")
            self.assertEqual(MULTI_ASSET_PKGBUILD,
                             pkgbuild.read_text(encoding="utf-8"))

        self.assertEqual("ok", row["status"])
        self.assertFalse(row.get("applied"))


class ReportTests(unittest.TestCase):
    def test_every_status_renders(self):
        rows = [
            {"package": "a", "repo": "o/a", "status": "ok", "tag": "v1.0.0",
             "current": "1.0.0"},
            {"package": "b", "repo": "o/b", "status": "skip",
             "reason": "上游无正式 release"},
            {"package": "c", "repo": "o/c", "status": "error", "reason": "boom"},
            {"package": "d", "repo": "o/d", "status": "bump", "tag": "v2.0.0",
             "mode": "codeload", "old": "111111111111", "new": "222222222222",
             "applied": True, "new_pkgver": "2.0.0", "pkgrel": "1",
             "old_commit": "111111111111", "new_commit": "222222222222"},
            {"package": "e", "repo": "o/e", "status": "bump", "tag": "v2.0.0",
             "mode": "assets", "old": "1.0.0", "new": "2.0.0", "applied": True,
             "new_pkgver": "2.0.0", "pkgrel": "1"},
            {"package": "f", "repo": "o/f", "status": "bump", "tag": "v2.0.0",
             "mode": "assets", "old": "1.0.0", "new": "2.0.0", "applied": False},
        ]
        report = mod.render_report(rows)
        for name in ("a", "b", "c", "d", "e", "f"):
            self.assertIn(name, report)
        self.assertIn("资产模式", report)


if __name__ == "__main__":
    unittest.main()
