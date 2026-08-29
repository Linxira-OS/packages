#!/usr/bin/env python3
"""每日上游同步：比对 PKGBUILD pin 与各上游仓的最新正式 Release。

用法：
    python3 scripts/sync-upstream.py                 # 只读，打印计划
    python3 scripts/sync-upstream.py --write         # 应用 PKGBUILD 修改
    python3 scripts/sync-upstream.py --write \
        --summary "$GITHUB_STEP_SUMMARY"             # CI：写 Markdown 汇总
    python3 scripts/sync-upstream.py --package linxira-catalog

行为约定见 upstream-sync.toml 头部注释。只认正式 Release（GitHub
releases/latest 天然排除 draft/prerelease），无 Release 的上游跳过，
绝不追 main HEAD。仅依赖标准库（Python >= 3.11）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tomllib
import urllib.error
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "upstream-sync.toml"
PKGDIR = REPO_ROOT / "packages"
API_BASE = "https://api.github.com"

# ---------------------------------------------------------------- GitHub API


class GitHub:
    def __init__(self, token: str | None):
        self.token = token
        self.calls = 0

    def _get(self, url: str) -> tuple[int, bytes]:
        req = urllib.request.Request(url, headers={
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "linxira-upstream-sync",
        })
        if self.token:
            req.add_header("Authorization", f"Bearer {self.token}")
        self.calls += 1
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()

    def latest_release(self, repo: str) -> tuple[str, str] | None:
        """返回 (tag, 该 tag 指向的 commit SHA)；无正式 release 时 None。"""
        status, body = self._get(f"{API_BASE}/repos/{repo}/releases/latest")
        if status == 404:
            return None
        if status != 200:
            raise RuntimeError(f"{repo}: releases/latest HTTP {status}: {body[:200]!r}")
        tag = json.loads(body)["tag_name"]
        return tag, self.commit_of(repo, tag)

    def commit_of(self, repo: str, ref: str) -> str:
        status, body = self._get(f"{API_BASE}/repos/{repo}/commits/{ref}")
        if status != 200:
            raise RuntimeError(f"{repo}: 解析 ref {ref!r} HTTP {status}")
        return json.loads(body)["sha"]

    def tarball_sha256(self, repo: str, commit: str) -> str:
        url = f"https://codeload.github.com/{repo}/tar.gz/{commit}"
        req = urllib.request.Request(url, headers={"User-Agent": "linxira-upstream-sync"})
        h = hashlib.sha256()
        with urllib.request.urlopen(req, timeout=120) as resp:
            while chunk := resp.read(1 << 20):
                h.update(chunk)
        return h.hexdigest()


# ------------------------------------------------------------- PKGBUILD 解析

def kv_value(text: str, key: str) -> str | None:
    m = re.search(rf"(?m)^{re.escape(key)}=(.*?)\s*$", text)
    return m.group(1).strip("'\"") if m else None


def block_span(text: str, name: str) -> tuple[int, int] | None:
    """返回 name=(...) 中括号内容的 (start, end) 绝对偏移；支持嵌套/引号。"""
    m = re.search(rf"(?m)^{re.escape(name)}\s*=\s*\(", text)
    if not m:
        return None
    i = m.end() - 1  # 指向 '('
    depth, in_s, in_d = 0, False, False
    while i < len(text):
        c = text[i]
        if c == "'" and not in_d:
            in_s = not in_s
        elif c == '"' and not in_s:
            in_d = not in_d
        elif not in_s and not in_d:
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return m.end(), i
        i += 1
    raise ValueError(f"{name}=( 括号不闭合")


TOKEN_RE = re.compile(r"'[^']*'|\"[^\"]*\"|[^\s]+")


def tokens_with_spans(text: str, lo: int, hi: int):
    out = []
    for m in TOKEN_RE.finditer(text, lo, hi):
        raw = m.group()
        out.append((raw.strip("'\""), m.start(), m.end()))
    return out


def detect_source(text: str) -> tuple[int, str]:
    """返回 (source 数组下标, 'codeload'|'git')；找不到可跟踪 source 则抛错。"""
    span = block_span(text, "source")
    if span is None:
        raise ValueError("没有 source=( 数组")
    for idx, (tok, _s, _e) in enumerate(tokens_with_spans(text, *span)):
        if "codeload.github.com" in tok:
            return idx, "codeload"
        if "#commit=$_commit" in tok:
            return idx, "git"
    raise ValueError("source 里没有 codeload URL 或 #commit=$_commit 的可跟踪条目")


def replace_token(text: str, lo: int, hi: int, index: int, new_raw: str) -> str:
    toks = tokens_with_spans(text, lo, hi)
    _, s, e = toks[index]
    return text[:s] + new_raw + text[e:]


def bump_pkgbuild(path: Path, *, pkgver: str, commit: str, sha256: str | None,
                  mode: str) -> dict:
    """就地改写 PKGBUILD，返回改动说明。纯文本操作，可对 fixture 测试。"""
    text = path.read_text(encoding="utf-8")

    src_idx, detected = detect_source(text)
    if detected != mode:
        raise ValueError(f"source 类型不符：期望 {mode}，实际 {detected}")

    old_ver = kv_value(text, "pkgver")
    old_commit = kv_value(text, "_commit")
    if old_ver is None or old_commit is None:
        raise ValueError("缺少 pkgver 或 _commit")

    new_rel = "1" if pkgver != old_ver else str(int(kv_value(text, "pkgrel") or "0") + 1)

    # 行级替换：pkgver / pkgrel / _commit（锚定行首赋值，不会误伤函数体）
    for key, val in (("pkgver", pkgver), ("pkgrel", new_rel), ("_commit", commit)):
        text, n = re.subn(rf"(?m)^({key}=).*?$", rf"\g<1>{val}", text, count=1)
        if n != 1:
            raise ValueError(f"替换 {key}= 失败")

    # 校验和只动 source 对应下标的那一项
    if mode == "codeload":
        if sha256 is None:
            raise ValueError("codeload source 需要新的 sha256")
        span = block_span(text, "sha256sums")
        toks = tokens_with_spans(text, *span)
        if len(toks) <= src_idx:
            raise ValueError("sha256sums 条目比 source 少，数组错位")
        text = replace_token(text, *span, src_idx, f"'{sha256}'")
        sum_note = f"sha256[{src_idx}] 重算"
    else:
        span = block_span(text, "sha256sums")
        cur = tokens_with_spans(text, *span)[src_idx][0]
        if cur.upper() != "SKIP":
            raise ValueError(f"git source 的校验和是 {cur!r} 而非 SKIP，拒绝自动改")
        sum_note = "git source（SKIP，无需重算）"

    path.write_text(text, encoding="utf-8")
    return {"old_pkgver": old_ver, "new_pkgver": pkgver,
            "old_commit": old_commit[:12], "new_commit": commit[:12],
            "pkgrel": new_rel, "checksum": sum_note}


# ---------------------------------------------------------------------- 主流程

VALID_PKGVER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+:~-]*$")


def load_track(config: Path, only: str | None) -> list[tuple[str, str]]:
    data = tomllib.loads(config.read_text(encoding="utf-8"))
    track = [(t["package"], t["repo"]) for t in data.get("track", [])]
    if only:
        track = [t for t in track if t[0] == only]
        if not track:
            sys.exit(f"upstream-sync.toml 里没有包 {only!r}")
    return track


def scan_one(gh: GitHub, package: str, repo: str, pkgbuild: Path,
             write: bool) -> dict:
    """扫描一个包并（可选）写入 bump。返回结果行；异常转成 error 行。"""
    row: dict = {"package": package, "repo": repo}
    try:
        if not pkgbuild.exists():
            raise FileNotFoundError(f"{pkgbuild} 不存在")
        text = pkgbuild.read_text(encoding="utf-8")
        rel = gh.latest_release(repo)
        if rel is None:
            row.update(status="skip", reason="上游无正式 release")
            return row

        tag, commit = rel
        # 版本防线：只认 vX.Y.Z / 数字开头的 tag，test-20260804 之类直接跳过
        ver = tag[1:] if tag[:1] in ("v", "V") else tag
        if not ver[:1].isdigit():
            row.update(status="skip",
                       reason=f"release tag `{tag}` 不是版本号，请在上游打规范 tag")
            return row
        if not VALID_PKGVER.match(ver):
            raise ValueError(f"tag {tag!r} 无法转成合法 pkgver")

        current_commit = kv_value(text, "_commit")
        if current_commit is None:
            raise ValueError("PKGBUILD 缺少 _commit")
        if commit == current_commit:
            row.update(status="ok", tag=tag, current=kv_value(text, "pkgver"))
            return row

        _idx, mode = detect_source(text)
        sha = gh.tarball_sha256(repo, commit) if mode == "codeload" else None
        info: dict | None = None
        if write:
            info = bump_pkgbuild(pkgbuild, pkgver=ver, commit=commit,
                                 sha256=sha, mode=mode)
        row.update(status="bump", tag=tag, mode=mode,
                   old=current_commit[:12], new=commit[:12],
                   applied=bool(info), **(info or {}))
    except Exception as e:  # 单个包失败不影响其余包
        row.update(status="error", reason=str(e))
    return row


def render_report(rows: list[dict]) -> str:
    lines = ["## 上游同步报告", "",
             "| 包 | 上游 release | 状态 |",
             "|---|---|---|"]
    for r in rows:
        if r["status"] == "bump":
            note = (f"→ `{r['new_pkgver']}` (rel={r['pkgrel']}, "
                    f"{r['old_commit']}…{r['new_commit']})"
                    if r.get("applied")
                    else f"`{r['old']}…` → `{r['new']}`（未写入，dry-run）")
            url = f"https://github.com/{r['repo']}/releases/tag/{r['tag']}"
            lines.append(f"| {r['package']} | [`{r['tag']}`]({url}) | {note} |")
        elif r["status"] == "ok":
            lines.append(f"| {r['package']} | `{r['tag']}` | 已是最新 |")
        elif r["status"] == "skip":
            lines.append(f"| {r['package']} | — | {r['reason']} |")
        else:
            lines.append(f"| {r['package']} | — | ⚠️ 错误：{r['reason']} |")
    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--write", action="store_true", help="应用修改（默认只读检查）")
    ap.add_argument("--package", help="只处理指定包")
    ap.add_argument("--summary", help="把 Markdown 汇总写入该文件")
    ap.add_argument("--json", action="store_true", help="逐行输出 JSON 结果")
    args = ap.parse_args()

    gh = GitHub(os.environ.get("GITHUB_TOKEN") or None)
    rows = [scan_one(gh, pkg, repo, PKGDIR / pkg / "PKGBUILD", args.write)
            for pkg, repo in load_track(CONFIG_PATH, args.package)]

    for r in rows:
        if args.json:
            print(json.dumps(r, ensure_ascii=False))

    report = render_report(rows)
    if args.summary:
        Path(args.summary).parent.mkdir(parents=True, exist_ok=True)
        Path(args.summary).write_text(report, encoding="utf-8")
    if not args.json:
        bumps = sum(1 for r in rows if r["status"] == "bump")
        print(report, end="")
        print(f"# 扫描 {len(rows)} 个包：落后 {bumps} 个，API 调用 {gh.calls} 次\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
