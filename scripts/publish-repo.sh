#!/usr/bin/env bash
set -euo pipefail

: "${LINXIRA_GPG_PRIVATE_KEY:?LINXIRA_GPG_PRIVATE_KEY is required}"
: "${LINXIRA_GPG_FINGERPRINT:?LINXIRA_GPG_FINGERPRINT is required}"

if [[ ! "$LINXIRA_GPG_FINGERPRINT" =~ ^[0-9A-Fa-f]{40}$ ]]; then
  echo "LINXIRA_GPG_FINGERPRINT must be a full 40-hex fingerprint" >&2
  exit 1
fi

install -d -m700 "$HOME/.gnupg"
printf '%s\n' "$LINXIRA_GPG_PRIVATE_KEY" | gpg --batch --import

imported_fingerprint=$(gpg --batch --with-colons --fingerprint "$LINXIRA_GPG_FINGERPRINT" \
  | awk -F: '$1 == "fpr" { print toupper($10); exit }')
expected_fingerprint=${LINXIRA_GPG_FINGERPRINT^^}

if [[ "$imported_fingerprint" != "$expected_fingerprint" ]]; then
  echo "Imported signing key does not match LINXIRA_GPG_FINGERPRINT" >&2
  exit 1
fi

repo_dir=${1:?repository output directory is required}
mkdir -p "$repo_dir/x86_64"
find artifacts -type f -name '*.pkg.tar.zst' -exec cp -f {} "$repo_dir/x86_64/" \;

shopt -s nullglob
packages=("$repo_dir"/x86_64/*.pkg.tar.zst)
if (( ${#packages[@]} == 0 )); then
  echo "No packages were downloaded" >&2
  exit 1
fi

: "${LINXIRA_GPG_PASSPHRASE:?LINXIRA_GPG_PASSPHRASE is required for signing}"

for package in "${packages[@]}"; do
  gpg --batch --pinentry-mode loopback --passphrase "$LINXIRA_GPG_PASSPHRASE"     --yes --local-user "$expected_fingerprint" --detach-sign "$package"
done

(
  cd "$repo_dir/x86_64"
  repo-add --sign --key "$expected_fingerprint" linxira.db.tar.gz ./*.pkg.tar.zst 2>/dev/null ||   repo-add --sign --key "$expected_fingerprint" linxira.db.tar.zst ./*.pkg.tar.zst
)

gpg --batch --armor --export "$expected_fingerprint" >"$repo_dir/linxira.gpg"
