#!/usr/bin/env bash
# 校验 APK 签名是家族主钥匙（b5aaac0e 前缀），防止 CI 静默回落 debug 签名。
set -euo pipefail
apk="$1"
expected_prefix="b5aaac0e"
actual="$(apksigner verify --print-certs "$apk" 2>/dev/null | awk '/SHA-256 digest/ {print $5; exit}')"
if [ -z "$actual" ]; then
  echo "无法读取签名（未签名或工具缺失）" >&2
  exit 1
fi
if [[ "$actual" != "$expected_prefix"* ]]; then
  echo "签名指纹不符：$actual（期望 $expected_prefix… 家族钥匙）" >&2
  exit 1
fi
echo "签名校验通过：$actual"
