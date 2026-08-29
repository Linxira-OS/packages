#!/usr/bin/env bash
# 把刚构建+签名好的包增量发布到公开仓 Linxira-OS/linxira-packages 并打 Release。
#
# 前置（由 packages.yml 的 publish job 提供）：
#   - ./artifacts/            本轮构建产物（download-artifact 结果）
#   - LINXIRA_CI_TOKEN        PAT，需对 Linxira-OS/linxira-packages 有 contents:write
#   - LINXIRA_GPG_*           签名三件套（见 README「密钥」）
#   - $1                      发布说明（取触发提交的 subject）
#
# 流程：克隆公开仓 → arch 容器内签新包 + 全量重建 db/files（与现有提交布局
# 一致：linxira.db{,.tar.zst,.sig} + linxira.files{,...}）→ 提交推送 →
# 生成 SHA256SUMS 并创建 GitHub Release。
set -euo pipefail

: "${LINXIRA_CI_TOKEN:?缺少 secret LINXIRA_CI_TOKEN（对 linxira-packages 需要 contents:write）}"
: "${LINXIRA_GPG_PRIVATE_KEY:?}" "${LINXIRA_GPG_FINGERPRINT:?}" "${LINXIRA_GPG_PASSPHRASE:?}"
summary=${1:?用法: deploy-to-linxira-packages.sh "<发布说明>"}

TARGET_REPO="Linxira-OS/linxira-packages"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
git clone --depth 1 \
  "https://x-access-token:${LINXIRA_CI_TOKEN}@github.com/${TARGET_REPO}.git" \
  "$work/repo"

docker run --rm \
  -e LINXIRA_GPG_PRIVATE_KEY -e LINXIRA_GPG_FINGERPRINT -e LINXIRA_GPG_PASSPHRASE \
  -v "$PWD:/workspace" -v "$work/repo:/target" \
  archlinux:base bash -euxo pipefail -c '
    pacman -Syu --noconfirm gnupg pacman >/dev/null
    install -d -m700 /root/.gnupg
    printf "%s\n" "$LINXIRA_GPG_PRIVATE_KEY" | gpg --batch --import
    FP=${LINXIRA_GPG_FINGERPRINT^^}
    [[ "$FP" =~ ^[0-9A-F]{40}$ ]]
    imported=$(gpg --batch --with-colons --fingerprint "$FP" | awk -F: "\$1==\"fpr\" {print toupper(\$10); exit}")
    [[ "$imported" == "$FP" ]]

    sign() { gpg --batch --pinentry-mode loopback --passphrase "$LINXIRA_GPG_PASSPHRASE" \
                   --yes --local-user "$FP" --detach-sign "$1"; }

    # 1) 新包拷入并逐个签名（旧包与其 sig 不动）
    find /workspace/artifacts -type f -name "*.pkg.tar.zst" | while read -r src; do
      cp -f "$src" /target/x86_64/
      sign "/target/x86_64/$(basename "$src")"
    done

    # 2) 全量重建 db/files（显式 .tar.zst 命名，避免 repo-add 扩展名歧义）
    cd /target/x86_64
    rm -f linxira.db linxira.db.tar.* linxira.files linxira.files.tar.*
    repo-add --sign --key "$FP" linxira.db.tar.zst ./*.pkg.tar.zst
    cp -f linxira.db.tar.zst linxira.db
    cp -f linxira.files.tar.zst linxira.files
    for f in linxira.db linxira.db.tar.zst linxira.files linxira.files.tar.zst; do
      sign "$f"
    done

    # 3) 校验和清单
    sha256sum ./*.pkg.tar.zst linxira.db linxira.db.tar.zst \
              linxira.files linxira.files.tar.zst > SHA256SUMS
  '

cd "$work/repo"
git config user.name "linxira-sync-bot"
git config user.email "admin@linxira.org"
git add -A
if git diff --cached --quiet; then
  echo "linxira-packages 无变化，跳过发布"
  exit 0
fi
git commit -m "publish(sync): ${summary}"
git push origin HEAD

tag="sync-$(date -u +%Y%m%d-%H%M%S)"
cd x86_64
GH_TOKEN="$LINXIRA_CI_TOKEN" gh release create "$tag" \
  --repo "$TARGET_REPO" --target "$(git -C .. rev-parse HEAD)" \
  --title "$tag" --notes "自动发布：${summary}
来源：Linxira-OS/packages 的 \`chore(bump)\` 合并流水线。
校验：\`sha256sum -c SHA256SUMS\`，验签指纹 E1A4155F457D1481CA85EE6BF9D157739534BC29。" \
  linxira.db linxira.db.sig linxira.db.tar.zst linxira.db.tar.zst.sig SHA256SUMS

echo "已发布 $TARGET_REPO@$tag"
