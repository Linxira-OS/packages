# Linxira 安全通告与应急缓解通道 · 设计文档

状态：设计稿 v1（2026-09-20）。实现排期在 packages 跟随链与内核引导逻辑之后。

## 1. 要解决的问题

当供应链路上任何一个软件包爆出关键问题（nginx 类网络服务组件、内核级漏洞、
CVE 等），**不等 Arch 官方仓库出修复包**：Linxira 第一时间以「缓解配置」的
形式下发到用户系统止血；等上游修复包进入 [linxira]/Arch 仓库、用户系统
完成更新之后，**自动把临时配置还原回原样**。

## 2. 总体结构

```
            (我们, 发布端)                         (用户系统)
  advisories 仓库 ──Pages──▶ advisories.json + .sig   │
        │                        │                    │  update timer 轮询
        │  GitHub Releases/RSS   ▼                    ▼
        └──human feed──▶  linxira-config advisory apply
                               │ 1. 验签(发布子钥)
                               │ 2. 版本范围命中判断
                               │ 3. 白名单动作执行(先备份)
                               ▼
                     /var/lib/linxira/mitigations/<id>/
                               │
        修复包就位(update 检测) ▼
                     linxira-config advisory revert(自动还原备份)
```

- 人工订阅：GitHub 原生 Atom（`https://github.com/Linxira-OS/<advisories>/releases.atom`），
  零自建成本；每个通告一个 Release。
- 机器通道：`advisories.json` + 分离签名 `.sig`，与 [linxira] 仓库同一 Pages
  体系发布（跟随 linxira-packages 的构建/发布流水线，或独立 advisories 仓库）。

## 3. 通告数据格式（advisories.json 条目）

```json
{
  "id": "LINXIRA-SA-2026-0007",
  "date": "2026-10-02T08:00:00Z",
  "severity": "critical",
  "title": "nginx http/2 stream 计算错误 (CVE-XXXX-XXXX)",
  "packages": [
    { "name": "nginx", "affected": "<1.27.4", "fixed_in": "1.27.4" }
  ],
  "actions": [
    {
      "type": "config-drop-in",
      "target": "/etc/nginx/conf.d/linxira-mitigation.conf",
      "payload_sha256": "…",
      "payload": "…"
    },
    { "type": "unit-stop", "unit": "nginx.service" }
  ],
  "expires": "2026-11-02",
  "status": "active"
}
```

- `affected` / `fixed_in` 用 vercmp 语义（与 pacman 一致）。
- `status`: `active`（生效中）/ `resolved`（修复包已就位，条目留档）/ `revoked`（误发，撤销）。
- 整个 json 由发布签名子钥（E1A4155F…/D477286C…，同 [linxira] 仓库）分离签名；
  指纹已经由 linxira-keyring 分发到所有用户系统 —— **验签是硬门槛，无签名不执行**。

## 4. 缓解动作白名单（安全边界的核心）

CLI 只执行以下枚举动作，通告携带任意命令一律拒收：

| type | 行为 | 说明 |
|---|---|---|
| `config-drop-in` | 原子写入目标配置文件 | 内容与 sha256 双校验；写前把原文件备份进状态目录 |
| `config-remove` | 删除本通道此前写入的文件 | 只允许删除带本通道标记头的文件 |
| `unit-stop` / `unit-start` | systemctl stop/start | 不得 mask；不得作用于 `.device`/`.mount` |
| `pacman-ignore` | 向 pacman.conf drop-in 写 IgnorePkg | 修复包就位后自动移除 |
| `hint` | 仅在 Welcome/CLI 展示提示 | 不改系统 |

禁止项（写入规范，实现时以白名单枚举强制）：任意命令执行、下载并执行、
修改白名单之外的任意路径、修改引导/内核参数。

## 5. 用户端状态机（CLI 侧）

- 状态目录：`/var/lib/linxira/mitigations/`，每通告一个子目录
  （原始文件备份 + `meta.json`），另有 `state.json` 汇总。
- 轮询：复用 `linxira-update.timer`（本轮已全局启用），update 拉取更新状态时
  顺带拉取 advisories.json；CLI 也可 `linxira-config advisory sync` 手动同步。
- 应用（apply）：
  1. 验签 → 解析 → 对本机已装包做 vercmp 命中判断；
  2. 未命中 → 只记录不动作；命中 → 按 severity 决定模式：
     `critical` 的 `config-drop-in`/`pacman-ignore` 可自动应用（默认配置可关），
     其余一律提示后由用户确认；
  3. 备份原文件 → 执行动作 → 记录状态（幂等，重复 apply 无副作用）。
- 还原（revert）：
  - 触发条件（任一）：本机包版本 ≥ `fixed_in`（update 完成升级后可见）；
    `status` 变为 `resolved/revoked`；超过 `expires`。
  - 动作：从备份原子写回原文件、逆向 `pacman-ignore`、恢复被 stop 的单元为
    原状态 → 标记 resolved。**还原失败不静默**：重试 + Welcome/CLI 显式报错。

## 6. 发布端流程（我们）

1. 在 advisories 仓库新增/修改通告条目 → PR 评审（至少一人复核动作白名单合规）。
2. 合并后 Actions 自动：全量 json 校验（schema + vercmp 语法 + 白名单 type 校验）
   → 签名 → 部署 Pages → 打 Release（喂 Atom/RSS）。
3. 修复包就位后：条目改 `resolved` 走同一流水线；用户端收到新 json 后自动还原。

## 7. 与现有组件的接口

- `linxira-update`：只增加"把已装包版本表暴露给 CLI"这一既有能力（pacman -Q），
  不承担任何配置写入 —— 写入一律由 CLI 的白名单执行器完成，责任单一。
- `linxira-config` CLI：新增 `advisory {sync,list,apply,status,revert}` 子命令；
  复用其现有 pkexec 最小授权框架。
- `linxira-welcome`：`status=active` 且命中本机的通告在状态页显示"已采取缓解措施"
  徽标；不新增横幅，避免与延后安装横幅争抢注意力。
- `[linxira]` 包仓库：本通道与包发布共用签名密钥与 Pages 体系，但通告仓库独立
  （advisories 变更不应触发包重建）。

## 8. 风险与对策

| 风险 | 对策 |
|---|---|
| 通道被冒充（远程改配置 = 远程入侵面） | 分离签名 + 本地指纹白名单 + 动作白名单枚举 + 严重度分级确认 |
| 缓解配置忘记还原 | 状态机以包版本为准自动还原；expires 兜底；还原失败显式报错 |
| 通告写错导致服务不可用 | 发布端 PR 评审 + Actions schema 校验；`config-drop-in` 先备份可回滚 |
| 用户离线收不到还原指令 | 包版本是还原判据，离线机器一旦联网升级即自愈；不依赖"收到 resolved 通告" |

## 9. 验收场景（实现完成后演练）

1. 伪造未签名通告 → CLI 拒收。
2. 发布 nginx 假 CVE 通告（config-drop-in + unit-stop）→ 离线 VM 命中 → 自动应用 →
   手工升级 nginx 到 fixed_in → 自动还原 → 状态页显示 resolved。
3. revoked 通告 → 已应用的机器自动回滚。
4. long-offline 机器连收 3 条通告 → 逐条幂等应用，无重复写入。
