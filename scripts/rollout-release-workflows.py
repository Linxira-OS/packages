#!/usr/bin/env python3
"""为 Linxira 系统软件仓批量铺 VERSION + release.yml(版本提交自动发 Release)。
排除: calamares/shelly(外部上游), zeta(独立开发, 稳定前不进系统包链)。
所有 GitHub 访问都经 gh api 子进程完成(认证与传输统一), 本脚本不做裸 HTTP。
"""
import json
import subprocess
import sys

REPOS = {
    "linxira-artwork": ("1.1.0", "master"),
    "linxira-catalog": ("3.1.0", "main"),
    "linxira-completion-agent": ("0.1.1", "main"),
    "linxira-component-manager": ("0.1.1", "main"),
    "linxira-components": ("0.7.0", "main"),
    "linxira-config-hub": ("2.2.2", "main"),
    "linxira-gaming-manager": ("0.3.0", "main"),
    "linxira-hardware-driver-manager": ("0.4.0", "main"),
    "linxira-hooks": ("1.1.0", "master"),
    "linxira-hwd-detector": ("1.23.0", "main"),
    "linxira-kernel-manager": ("0.1.0", "main"),
    "linxira-package-center": ("0.2.1", "main"),
    "linxira-recovery-diagnostics": ("0.2.0", "main"),
    "linxira-update": ("0.1.0", "main"),
    "linxira-welcome": ("1.0.1", "main"),
    "linxira-wiki": ("0.1.0", "master"),
}

WORKFLOW = """name: Release on version bump

# VERSION 文件变更(或手动触发) => 若对应 tag 的 Release 不存在则自动创建。
# [linxira] 包仓库的 auto-bump 每日扫描正式 Release 并自动 bump/合并/发布。
on:
  push:
    # 同时监听 main/master: 硬编码单一分支名时, 默认分支一改整条发布链就静默死亡
    # (linxira-artwork 2026-10 即因此停在 1.0.3, 见 CI 链路审计)。
    branches: [main, master]
    paths: ["VERSION"]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Create release if tag missing
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          ver=$(tr -d '[:space:]' < VERSION)
          tag="v${ver}"
          if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
            echo "release $tag already exists; nothing to do"
            exit 0
          fi
          gh release create "$tag" --target "$GITHUB_SHA" --title "$tag" \\
            --notes "Automated release for version ${ver} (VERSION file bump)."
"""


def gh_api(method: str, path: str, payload: dict | None = None) -> dict:
    cmd = ["gh", "api", "--method", method, path]
    if payload is not None:
        cmd += ["--input", "-"]
    result = subprocess.run(
        cmd, input=json.dumps(payload) if payload is not None else None,
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}


def file_sha(repo: str, branch: str, path: str) -> str | None:
    try:
        return gh_api("GET", f"/repos/Linxira-OS/{repo}/contents/{path}?ref={branch}").get("sha")
    except RuntimeError:
        return None


def put_file(repo: str, branch: str, path: str, content: str, message: str) -> None:
    payload = {
        "message": message,
        "content": content.encode().hex(),  # placeholder replaced below
    }
    import base64
    payload["content"] = base64.b64encode(content.encode()).decode()
    sha = file_sha(repo, branch, path)
    if sha:
        payload["sha"] = sha
    gh_api("PUT", f"/repos/Linxira-OS/{repo}/contents/{path}", payload)
    print(f"  wrote {path}")


only = sys.argv[1:] or list(REPOS)
failed = []
for repo in only:
    version, branch = REPOS[repo]
    print(f"== {repo} ({version}, {branch})")
    try:
        put_file(repo, branch, "VERSION", version + "\n",
                 f"chore(release): record version {version} in VERSION file")
        put_file(repo, branch, ".github/workflows/release.yml", WORKFLOW,
                 "ci: auto-create GitHub Release when VERSION file bumps")
        # 两次 PUT = 两个 commit ⇒ release.yml 上线那次提交不含 VERSION 变更, 不匹配
        # paths:["VERSION"], 首次铺开永远不会自动触发(2026-08 rollout 的 5 个仓因此
        # 无 Release)。补一次 dispatch; 工作流对已存在的 tag 幂等跳过。
        gh_api("POST",
               f"/repos/Linxira-OS/{repo}/actions/workflows/release.yml/dispatches",
               {"ref": branch})
        print("  dispatched release workflow")
    except Exception as exc:
        failed.append(repo)
        print(f"  !! FAILED: {exc}")
if failed:
    print("FAILED repos:", ", ".join(failed))
    sys.exit(1)
