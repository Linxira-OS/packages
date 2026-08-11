# AI Agent 操作规范(packages 仓库)

本文件供 AI agent(如 Trae/Claude/Cursor)在本仓库执行包更新、修复、CI
排查时遵循。人类贡献者请看 [CONTRIBUTING.md](../CONTRIBUTING.md)。

## 核心约束(违反即 CI 必挂)

### 1. PKGBUILD 与 check-boundaries.sh 必须同步

**改 PKGBUILD 的 `_commit` 或 `sha256sums` 后,必须同步修改
[scripts/check-boundaries.sh](../scripts/check-boundaries.sh) 里对应的
硬编码 hash,否则 CI boundaries job 必挂。**

校验脚本里每个包有两行:
```bash
grep -q '<_commit前若干位>' packages/<pkg>/PKGBUILD
grep -q '<sha256前若干位>' packages/<pkg>/PKGBUILD
```
PKGBUILD 改完后,把这两行的 hash 也更新成新值。

### 2. _commit 与 sha256 必须同时更新

不同 commit 的 codeload tarball 必然产生不同 sha256。只改 _commit 不改
sha256,或只改 sha256 不改 _commit,CI 的 makepkg 校验必挂。

### 3. 不要 git add -A

用具体文件名:
```bash
git add packages/<pkg>/PKGBUILD scripts/check-boundaries.sh
```
防止带入 `.pkg.tar.zst`、`src/`、`pkg/` 等构建产物。

### 4. 不要引入 CachyOS/AUR/Seafoam 仓库引用

check-boundaries.sh 会 grep 拒绝以下字符串出现在 PKGBUILD 里:
- `cachyos` / `CachyOS`(除了 chwd-detector 的 `url` 字段描述上游来源)
- `aur` / `AUR`(作为仓库引用)
- `seafoam` / `Seafoam`(除了 shelly 的 `url` 字段)

### 5. PKGBUILD 必须是 LF 行尾

Windows 上 checkout 会产生 CRLF,makepkg 解析可能出错。本仓库已有
`.gitattributes` 强制 `*.sh` 和 `PKGBUILD` 用 LF。提交前若手动编辑过,
用 `dos2unix` 或 `git add --renormalize` 确保 LF。

## 更新包的完整流程(机器可执行)

当需要把某个包的 PKGBUILD 更新到源码仓库最新 commit 时:

### 输入
- 包名 `pkgname`(如 `linxira-catalog`)
- 源码仓库 org/repo(如 `Linxira-OS/linxira-catalog`)
- 分支(默认 `main`,但 artwork/hooks 是 `master`,shelly 是 `development`)

### 步骤

1. **查源码仓库最新 commit**:
   ```bash
   gh api repos/Linxira-OS/<repo>/branches/<branch> --jq .commit.sha
   ```
   得到完整 40 位 SHA。

2. **下载 tarball 算 sha256**(非 git source 的包):
   ```bash
   curl -L "https://codeload.github.com/Linxira-OS/<repo>/tar.gz/<full_sha>" -o /tmp/tb.tar.gz
   sha256sum /tmp/tb.tar.gz | cut -d' ' -f1
   ```
   git source 的包(linxira-hooks)跳过此步,sha256 保持 `SKIP`。

3. **读 PKGBUILD,确认需要改哪些行**:
   - `_commit=` 行
   - `sha256sums=('...')` 行
   - 如果源码有版本号变化,还要改 `pkgver=` / `pkgrel=`

4. **改 PKGBUILD**(用 Edit 工具,精确替换):
   - `_commit=<旧值>` → `_commit=<新40位SHA>`
   - `sha256sums=('<旧值>')` → `sha256sums=('<新值>')`

5. **改 check-boundaries.sh**:
   - 用 Grep 找到 `packages/<pkg>/PKGBUILD` 对应的两行
   - 把 hash 更新成 PKGBUILD 里的新值(取前 8-12 位即可,与现有风格一致)

6. **本地跑边界校验**:
   ```bash
   cd f:\Linxira-OS\packages
   bash scripts/check-boundaries.sh
   ```
   应输出 `OK: boundaries check passed` 之类。如果失败,说明 PKGBUILD
   与 check-boundaries.sh 不同步。

7. **提交**:
   ```bash
   git add packages/<pkg>/PKGBUILD scripts/check-boundaries.sh
   git commit -m "update <pkg> to <commit前7位>"
   git push
   ```

8. **等 CI**:
   ```bash
   gh api "repos/Linxira-OS/packages/actions/runs?per_page=1" --jq '.workflow_runs[0] | "\(.status) \(.conclusion // \"running\")"'
   ```
   等 status=completed 且 conclusion=success。

## 批量更新多个包

如果需要一次性更新多个包(如今天的 11 个包对齐):

1. 对每个包并行执行步骤 1-2(查 commit + 算 sha256)
2. 串行执行步骤 3-5(改文件,避免冲突)
3. 一次性提交所有改动:
   ```bash
   git add packages/*/PKGBUILD scripts/check-boundaries.sh
   git commit -m "update 11 packages to latest commits

   - linxira-artwork: 6e56f3f → 8b92b66
   - linxira-catalog: 89b2559 → 9dd16cd
   - ..."
   git push
   ```

## CI 失败排查流程

### boundaries job 失败

读 [scripts/check-boundaries.sh](../scripts/check-boundaries.sh),看哪个
grep 失败了。通常是 PKGBUILD 与脚本不同步。

### build/system-stack job 失败

1. 查失败的 job id:
   ```bash
   gh api repos/Linxira-OS/packages/actions/runs/<run_id>/jobs --jq '.jobs[] | select(.conclusion=="failure") | "\(.name) \(.id)"'
   ```

2. 拉日志,过滤关键错误:
   ```bash
   gh api repos/Linxira-OS/packages/actions/jobs/<job_id>/logs 2>&1 | grep -E "==> ERROR|error\[|cannot find|not found|FAILED|exit code"
   ```

3. 常见错误模式:
   - `One or more files did not pass the validity check!` → sha256 不匹配
   - `error: header file not found` / `bindgen failed` → makedepends 缺系统包
   - `error[E0432]: unresolved import` → Rust lib crate 名与测试 import 不一致
   - `cannot update the lock file because --locked` → Cargo.lock 与 Cargo.toml 不同步

### makedepends 缺失的处理

如果 CI 报 `pci/pci.h` 或 `libusb-1.0/libusb.h` 之类头文件缺失,在
PKGBUILD 的 `makedepends=(...)` 里加对应的 Arch 包:
- `pci/pci.h` → `libpciaccess`
- `libusb-1.0/libusb.h` → `libusb`

Arch 包名查询:https://archlinux.org/packages/ 搜头文件名。

## 各包默认分支速查

| 包 | 仓库 | 默认分支 |
|---|---|---|
| linxira-artwork | Linxira-OS/linxira-artwork | `master` |
| linxira-hooks | Linxira-OS/linxira-hooks | `master` |
| shelly | Seafoam-Labs/Shelly-ALPM | `development` |
| 其他所有 linxira-* | Linxira-OS/linxira-* | `main` |
| calamares | calamares/calamares | 用 release tag,不用分支 |

## 各包 source 模式速查

| 模式 | 包 | sha256 |
|---|---|---|
| codeload commit | artwork, catalog, chwd-detector, completion-agent, component-manager, components, config-hub, gaming-manager, hardware-driver-manager, kernel-manager, package-center, recovery-diagnostics, update, welcome, shelly | 需要 |
| release tarball | calamares | 需要(上游发布) |
| git source | hooks | `SKIP` |
| 本地文件 | keyring | 需要(本地 .gpg) |

## 文档维护

- [README.md](../README.md):仓库说明 + 各包用途(人类可读)
- [RELEASE.md](../RELEASE.md):发布流程 + 密钥管理
- [CONTRIBUTING.md](../CONTRIBUTING.md):人类贡献指南
- [docs/MAINTAINER_HANDOFF.md](MAINTAINER_HANDOFF.md):维护者交接(注意:可能过期,以 git log 为准)
- 本文件:AI agent 操作规范

如果发现文档与实际代码不一致,**以代码为准**,并顺手修文档。
