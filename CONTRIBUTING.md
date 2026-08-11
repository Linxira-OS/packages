# 贡献指南

本仓库集中管理 Linxira OS 所有自研包的 PKGBUILD。CI 在干净的 Arch
Linux 容器里构建每个包,签名后发布到 GitHub Pages 上的 `[linxira]` 仓库。

## 仓库结构

```
packages/
├── packages/                  # 每个子目录 = 一个包
│   ├── calamares/             # 采用的上游安装器(release tarball + patch)
│   ├── linxira-catalog/       # 自研包(codeload commit 模式)
│   ├── linxira-chwd-detector/ # 自研包
│   ├── shelly/                # 采用的上游包(codeload commit 模式)
│   └── ...                    # 共 18 个包
├── scripts/
│   ├── check-boundaries.sh    # 边界校验(CI 第一道门,改 PKGBUILD 必须同步改)
│   └── publish-repo.sh        # 签名 + repo-add + GitHub Pages 发布
├── .github/workflows/
│   └── packages.yml           # CI:boundaries → build(4包) + system-stack(13包) → publish
├── README.md                  # 仓库说明 + 各包用途
├── RELEASE.md                 # 发布流程 + 密钥管理
└── CONTRIBUTING.md            # 本文件
```

## 两种包模式

### 模式 A:codeload commit 模式(大多数自研包)

```bash
_commit=<40位SHA>
source=("$pkgname-$_commit.tar.gz::https://codeload.github.com/Linxira-OS/$pkgname/tar.gz/$_commit")
sha256sums=('<tarball的sha256>')
```

源码固定到某个 commit,makepkg 自动从 codeload 下载,sha256 校验完整性。

### 模式 B:release tarball 模式(calamares)

```bash
source=("https://github.com/calamares/calamares/releases/download/v${pkgver}/calamares-${pkgver}.tar.gz")
sha256sums=('<上游发布的sha256>')
```

用上游 release tarball,靠 tag 不可变。

### 模式 C:git source 模式(linxira-hooks)

```bash
source=("git+$url.git#commit=$_commit")
sha256sums=('SKIP')
```

git source 不校验 sha256(因为 git clone 自带完整性校验)。

### 模式 D:本地文件模式(linxira-keyring)

```bash
source=("linxira.gpg")
sha256sums=('<本地文件的sha256>')
```

keyring 的 .gpg 文件直接放在 PKGBUILD 同目录。

## 更新一个包(最常见操作)

当某个自研仓库(linxira-catalog 等)有了新 commit,需要更新 packages
仓库里的 PKGBUILD:

### 第 1 步:获取新 commit 的完整 SHA

```bash
# 在源码仓库
git log --oneline -1
# 输出: 9dd16cda... (取完整 40 位 SHA)
```

### 第 2 步:更新 PKGBUILD

改两个地方:
1. `_commit=<新的40位SHA>`
2. `sha256sums=('<新tarball的sha256>')`

计算新 sha256(Arch 环境):

```bash
# 方法 1:updpkgsums(推荐,自动改 PKGBUILD)
cd packages/linxira-catalog
updpkgsums

# 方法 2:makepkg -g(只输出新 sha256,手动粘贴)
cd packages/linxira-catalog
makepkg -g

# 方法 3:手动下载算
curl -L "https://codeload.github.com/Linxira-OS/linxira-catalog/tar.gz/<commit>" -o /tmp/tarball.tar.gz
sha256sum /tmp/tarball.tar.gz
```

如果 pkgver 或 pkgrel 也需要更新,一并修改。

### 第 3 步:同步 check-boundaries.sh

**这一步最容易遗漏。** [scripts/check-boundaries.sh](scripts/check-boundaries.sh)
把每个包的 `_commit` 和 `sha256sums` 硬编码了,改了 PKGBUILD 必须同步改
这个脚本里的对应行,否则 CI 的 boundaries job 会失败。

```bash
# 找到你的包在 check-boundaries.sh 里的行
grep linxira-catalog scripts/check-boundaries.sh
# 输出两行:
#   grep -q '89b25593...' packages/linxira-catalog/PKGBUILD
#   grep -q 'bdf3657d...' packages/linxira-catalog/PKGBUILD
# 把这两个 hash 更新成 PKGBUILD 里的新值
```

### 第 4 步:本地验证

```bash
# 跑边界校验(CI 同款)
bash scripts/check-boundaries.sh

# 如果本地有 Arch 环境,试着构建
cd packages/linxira-catalog
makepkg -f
```

### 第 5 步:提交

```bash
git add packages/<pkg>/PKGBUILD scripts/check-boundaries.sh
git commit -m "update <pkg> to <commit前7位>"
git push
```

push 后 CI 自动跑:boundaries → build/system-stack。如果 CI 绿了,包就
自动构建好了(artifact 可下载)。

## CI 流水线

```
push/PR
  │
  ├─ boundaries          # check-boundaries.sh(秒级)
  │
  ├─ build (matrix)      # calamares / artwork / hooks / shelly
  │   └─ docker archlinux:base-devel → makepkg
  │
  ├─ system-stack        # 13 个 linxira-* 包,按依赖顺序构建
  │   └─ docker archlinux:base-devel → makepkg + pacman -U(装进容器供后续包依赖)
  │
  └─ publish (仅手动触发)  # 签名 + repo-add → GitHub Pages
```

### CI 失败的常见原因

| 原因 | 表现 | 解决 |
|------|------|------|
| sha256 不匹配 | `==> ERROR: One or more files did not pass the validity check!` | 重算 sha256: `makepkg -g` |
| _commit 过期但 sha256 没更新 | 同上 | 同时更新 _commit 和 sha256 |
| check-boundaries.sh 没同步 | `boundaries` job 失败 | 同步硬编码的 _commit/sha256 |
| makedepends 缺失 | `error: header file not found` 或 `bindgen failed` | 在 PKGBUILD makedepends 里加缺失的包 |
| CRLF 问题 | makepkg 解析 PKGBUILD 报奇怪错误 | 确保 PKGBUILD 是 LF 行尾(用 `.gitattributes` 或 `dos2unix`) |

## 添加新包

1. 在 `packages/` 下创建子目录,放 PKGBUILD
2. 如果有 patch 或额外文件,放在同目录
3. 如果包需要进 system-stack,在 `packages.yml` 的 `packages=(...)` 数组里加包名
4. 如果需要边界校验,在 `check-boundaries.sh` 里加校验规则
5. 确保包的 `groups=('linxira')`,这样 `pacman -S linxira` 能发现它

## 密钥与签名

详见 [RELEASE.md](RELEASE.md)。要点:

- 包签名用签名子密钥,GitHub Actions secret `LINXIRA_GPG_PRIVATE_KEY` +
  `LINXIRA_GPG_FINGERPRINT`
- 主密钥离线保管,签名子密钥仅在 CI 使用
- `linxira-keyring` 包分发公钥,用户装了这个包才能验证 `[linxira]` 仓库的包

## 不要做的事

- **不要用 `git add -A`**:可能带入意外文件(如 `.pkg.tar.zst` 构建产物)。用具体文件名 `git add packages/<pkg>/PKGBUILD`
- **不要手工 tar 打包源码**:PKGBUILD 的 source 必须用 codeload URL 或 release tarball,不能引用本地路径(linxira-keyring 除外)
- **不要跳过 check-boundaries.sh**:它是 CI 第一道门,本地跑不过 CI 一定挂
- **不要改 _commit 但不改 sha256**:不同 commit 的 tarball 必然有不同的 sha256
- **不要在 PKGBUILD 里写 CachyOS/AUR/Seafoam 仓库引用**:check-boundaries.sh 会拒绝
