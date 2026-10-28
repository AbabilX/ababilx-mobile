#!/usr/bin/env bash
# Verifies tool/mirror_public_prepare.sh strips signing material and refuses
# to leave tracked-looking secrets in the tree that will be published.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREPARE="$ROOT/tool/mirror_public_prepare.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/android" "$tmp/assets"
printf 'storePassword=x\n' >"$tmp/android/key.properties"
printf 'example\n' >"$tmp/android/key.properties.example"
printf 'fake-jks\n' >"$tmp/upload-keystore.jks"
printf 'fake\n' >"$tmp/android/debug.keystore"
printf 'keep\n' >"$tmp/assets/logo.png"
printf 'keep\n' >"$tmp/README.md"

"$PREPARE" "$tmp"

test ! -e "$tmp/android/key.properties"
test ! -e "$tmp/upload-keystore.jks"
test ! -e "$tmp/android/debug.keystore"
test -f "$tmp/android/key.properties.example"
test -f "$tmp/assets/logo.png"
test -f "$tmp/README.md"

# Re-inject a secret after prepare would be a workflow bug; the checker must fail.
printf 'leak\n' >"$tmp/sneaky.jks"
if "$PREPARE" --check-only "$tmp"; then
  echo "expected check-only to fail when .jks remains" >&2
  exit 1
fi

echo "mirror_public_prepare_test: ok"
