# Linxira 发布与可复现构建流程

本文件定义如何从"本地编译+手动传递离线包"迁移到**源码在 GitHub、构建脚本自动拉取、任何人可复现**的规范化流程。

## 现状与目标

| 环节 | 现状(临时) | 目标(规范化) |
|---|---|---|
| 源码来源 | 本地 git-archive 打包上传构建机 | 源码 push GitHub,PKGBUILD `source=` 用 codeload URL,makepkg 自动拉取 |
| 自研包获取 | `build-direct-iso.sh --*-package PATH` 传本地编译好的包 | 从 `[linxira]` 仓库/GitHub Releases 拉取签名包 |
| 包签名 | gpg 分离签名(构建机) | 签名子密钥 + `repo-add --sign`,包与 db 全签名 |
| 更新追踪 | linxira-update 报"无仓库"警告 | 装 linxira-keyring 后启用 `[linxira]`,可追踪更新 |
| 构建机 | 原版 Arch 手工维护 | 自研系统内建构建环境,依赖清单化 |

## 可复现构建步骤(第三方或未来开发卡)

1. **拉取源码**:`git clone` 目标仓库(linxira-components 等),commit 由 PKGBUILD `_commit` 固定。
2. **构建包**:在 Arch 环境对 `packages/packages/<pkg>` 目录执行 `makepkg`(PKGBUILD source 指向 codeload,自动下载固定 commit 的源码归档,sha256 校验)。
3. **签名**:发布者用签名子密钥 `31156EC1A740B2884F8110235EF193D3392B8D7B` 对包生成分离签名(`.sig`)。
4. **入仓库**:`repo-add --sign -R linxira.db.tar.zst <pkg>.pkg.tar.zst` 更新 `[linxira]` 数据库。
5. **发布**:更新后的包 + db + sig 提交到 `Linxira-OS.github.io/public/packages/x86_64/`,push 后 GitHub Pages Actions 自动部署。

## [linxira] 仓库

- URL:`https://linxira-os.github.io/packages/x86_64`
- 启用方式:先装 `linxira-keyring`(信任发布密钥),再在 `/etc/pacman.conf` 添加:

```
[linxira]
Server = https://linxira-os.github.io/packages/$arch
SigLevel = Required DatabaseOptional
```

- 密钥指纹(发布文档固定):`7CE0D31F4A71657AD66B7854BFF6AA69F55A30B8`(主密钥)/ 签名子密钥 `31156EC1A740B2884F8110235EF193D3392B8D7B`

## ISO 构建集成(规范化方向)

- `build-direct-iso.sh` 目前接收本地包路径参数(`--*-package PATH`)。
- 规范化方向:增加"自 `[linxira]` 仓库拉取指定版本自研包"模式(按 `_commit`/版本号解析),本地编译包仅作为开发期回退。
- ISO 内离线仓库仍用固定包集(保证安装离线可用),与 `[linxira]` 仓库保持一致来源(同一构建产物)。

## 发布检查清单(每次发布自研包)

1. 源码 commit 已 push 到 GitHub(`git push origin HEAD`)。
2. PKGBUILD `_commit` 指向该 commit,codeload URL 可访问,sha256 与 codeload 归档一致。
3. `makepkg` 在干净环境构建通过(含 `check()`)。
4. 包已用签名子密钥生成 `.sig`;`repo-add --sign` 更新 db。
5. `[linxira]` 线上可下载 db + 包 + sig;在干净系统验证:`pacman -Sy linxira-artwork` 安装成功。
6. 正式发布前:发布密钥(主密钥)应加口令并离线加密备份;签名子密钥仅存于签名机/CI。

## 安全约定(REPOSITORY_STRATEGY 节选)

- 离线主密钥 cert 专用签名子密钥;CI/构建机仅持有签名子密钥。
- 包与仓库数据库全部签名;公钥指纹 pin 在源码与发布文档。
- 签名密钥永不进入 ISO 源码树或公开构建镜像。
- 签名材料不可用时构建必须失败关闭(fail closed)。

## 任何人可编译(快速开始)

前提:Arch Linux(或 Linxira OS)+ `base-devel`(makepkg)。

```bash
# 1. 拉取构建配方(所有自研包 PKGBUILD + 边界校验 + 发布脚本)
git clone https://github.com/Linxira-OS/packages.git
cd packages

# 2. 构建单个包(自动从 codeload 拉取固定 commit 源码 + sha256 校验)
cd packages/linxira-components
makepkg -f            # 产出 linxira-components-0.7.0-4-any.pkg.tar.zst

# 3. 或构建全部包 + 生成签名仓库(发布者专用,需要签名子密钥)
cd ../../
./scripts/check-boundaries.sh   # 边界校验(CI 同款)
LINXIRA_GPG_PRIVATE_KEY="$(cat signing-subkey.asc)" \
LINXIRA_GPG_FINGERPRINT=31156EC1A740B2884F8110235EF193D3392B8D7B \
./scripts/publish-repo.sh ~/linxira-repo
```

## 镜像(ISO)托管方案

早期测试版 ISO 的托管选择(按 REPOSITORY_STRATEGY:GitHub Releases 承载早期 ISO + 分离签名):

1. **GitHub Releases(首选)**:给 `linxira-os`(或独立 `linxira-iso` 仓库)打 tag 发 Release,上传 ISO + SHA256SUMS + 分离签名(.sig)。URL 稳定、自带下载统计、支持断点。
   - ISO 签名用发布签名子密钥 `gpg --detach-sign --armor linxira-*.iso`,下载者用公钥指纹验证。
2. GitHub Pages `packages/` 目录(仅托管 pacman 包仓库,不托管大体积 ISO)。
3. 正式发布后:迁移到自有 CDN/对象存储(规划项)。

下载校验示例:

```bash
curl -L -O https://github.com/Linxira-OS/<repo>/releases/download/<tag>/linxira-*.iso
curl -L -O https://github.com/Linxira-OS/<repo>/releases/download/<tag>/linxira-*.iso.sig
gpg --keyserver keyserver.ubuntu.com --recv-keys 7CE0D31F4A71657AD66B7854BFF6AA69F55A30B8
gpg --verify linxira-*.iso.sig linxira-*.iso
```
