# Shelly — 上游与本地改动

本包重新打包上游 Shelly，并打一个本地补丁。为满足 GPL-3.0 的分发义务，此文件随包安装到
`/usr/share/doc/shelly/UPSTREAM.md`。

| 项 | 值 |
|---|---|
| 上游 | `Seafoam-Labs/Shelly-ALPM` |
| 版本/提交 | 见 `PKGBUILD` 的 `_commit` 与 `pkgver` |
| 上游许可 | GPL-3.0-only（见 `PKGBUILD` 的 `license=`；许可全文随包安装到 `/usr/share/licenses/shelly/LICENSE`） |
| 获取源码 | `git clone https://github.com/Seafoam-Labs/Shelly-ALPM && git checkout <_commit>` |

## Linxira 的改动

- `linxira-safety-policy.patch`：收紧激进清理策略（详见补丁文件本身）。

除该补丁外，本包不做源码改动；二进制构建参数见 `PKGBUILD`。

## 联系

问题请提交到 <https://github.com/Linxira-OS/packages/issues>。
