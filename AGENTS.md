# packages · Agent 开发规范

> **档位:S(治理与发布核心)**
> 本仓职责:Linxira OS 官方 Arch 软件包定义(PKGBUILD)与仓库发布流水线。
> **本仓已有中文 AI 操作规范 [`docs/AGENT-GUIDELINES.md`](docs/AGENT-GUIDELINES.md) —— 更新包、CI 排查、提交与批量更新的具体流程一律以它为准;本文件只补充职责、边界、目录与校验概览,不重复其内容。**
> 通用条款一律见工作区总纲 `f:\Linxira-OS\AGENTS.md` 与发布规范 `linxira-os/docs/RELEASE_STANDARD.md`。
> 冲突时以本文件为准。

## 职责与边界
- 归属:`owns: [pkgbuilds, package-ci, signed-repository-publication]`,lifecycle `active`。
- 每个自研包或明确收养的源码构建集成包 = `packages/<pkg>/` 下一个钉死 commit / 不可变源的 PKGBUILD。
- 发布产物同步到 `linxira-packages`(签名仓库),再由 `linxira-iso-direct` 消费;本仓**不手工改下游仓库**。
- 例外包:`shelly`(源码构建 GPL-3.0 例外,禁用删除 pacman lock 的危险动作)、`calamares`(收养官方 3.3.14 上游发布,
  不用 CachyOS fork)。用途详见 `README.md`。

## 目录布局
- `packages/<pkg>/PKGBUILD` —— 21 个包(`calamares`、`shelly`、`zetabin` 与 `linxira-*`)。
- `scripts/`:
  - `check-boundaries.sh` —— 语义边界 + 结构校验(CI `boundaries` job)。
  - `publish-repo.sh` —— 签名 + `repo-add` 建仓库。
  - `deploy-to-linxira-packages.sh` —— 同步签名产物到 `Linxira-OS/linxira-packages` 并打 `sync-*` Release。
  - `sync-upstream.py` / `rollout-release-workflows.py` —— 上游 release 同步。
- `.github/workflows/`:`packages.yml`(边界 → 构建 → 签名发布 → Pages)、`auto-bump.yml`(每日上游同步 PR + 自动 squash 合并)。
- `upstream-sync.toml` —— 自动 bump 白名单(不在表内的包永不自动 bump)。
- 文档:`README.md`、`RELEASE.md`、`CONTRIBUTING.md`、`docs/MAINTAINER_HANDOFF.md`、`docs/AGENT-GUIDELINES.md`、`docs/advisory-channel-design.md`。

## 构建与校验
```bash
# 本地边界校验(改任何 PKGBUILD 后必跑)
bash scripts/check-boundaries.sh        # 通过即 PKGBUILD 与脚本同步;失败见脚本打印的行号
# 单包构建(纯 Arch 环境,与 CI 一致)
cd packages/<pkg> && makepkg --syncdeps --noconfirm --clean --cleanbuild
```
- 完整更新流程(查最新 commit → 算 sha256 → 改 `_commit`/`sha256sums` → 同步 `check-boundaries.sh` → 提交 → 等 CI)
  见 `docs/AGENT-GUIDELINES.md`。

## 发布与签名
- 链:源仓改 `VERSION` → `release.yml` 建 v-tag → `auto-bump.yml` 扫描建 **chore(bump)** PR → 自动 squash 合并
  → `packages.yml` 构建+签名 → 同步 `linxira-packages`。
- `packages.yml` 的 `pull_request` **跳过 publish 是安全设计**,非故障;真正发布在 squash 合并后的 push 事件。
- 合并 bump PR 必须用 **squash merge**(保留 `chore(bump)` 标记,发布 job 靠它判定)。
- 所需密钥:`LINXIRA_GPG_PRIVATE_KEY` / `LINXIRA_GPG_FINGERPRINT` / `LINXIRA_GPG_PASSPHRASE`;
  自动同步腿另需 `LINXIRA_CI_TOKEN`。密钥金库见 `linxira-keys`。

## 禁区
- 禁止引入 `cachyos` / `aur` / `seafoam` 仓库引用(`check-boundaries.sh` 会拒);PKGBUILD 必须 LF。
- 改 `_commit` 或 `sha256sums` 后**必须同步更新** `scripts/check-boundaries.sh` 中对应 hash;`_commit` 与 `sha256` 必须同时改。
- 不要 `git add -A`(防止带入 `.pkg.tar.zst` / `src/` / `pkg/`);不要手工 bump 绕开自动链。
- 分支 `main`。

## 关联文档
- **`docs/AGENT-GUIDELINES.md`(本仓 AI 操作规范,优先阅读)**、`RELEASE.md`、`CONTRIBUTING.md`。
- 工作区总纲;发布规范;`linxira-keys/README.md`;`linxira-packages/README.md`。