#!/usr/bin/env bash
set -euo pipefail

if grep -R -n -E "(provides|conflicts|replaces)=\([^)]*cachyos-hooks" packages; then
  echo "linxira-hooks must coexist with cachyos-hooks" >&2
  exit 1
fi

if grep -R -n -E "Linxira (Package Installer|Kernel Manager)" packages; then
  echo "Upstream CachyOS tool identities must not be renamed" >&2
  exit 1
fi

for package in packages/*/PKGBUILD; do
  bash -n "$package"
done
