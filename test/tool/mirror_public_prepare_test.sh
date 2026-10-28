#!/usr/bin/env bash
# Verifies tool/mirror_public_prepare.sh strips signing material and refuses
# to leave tracked-looking secrets in the tree that will be published.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PREPARE="$ROOT/tool/mirror_public_prepare.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/android/app" "$tmp/assets" "$tmp/.github/workflows"
printf 'storePassword=x\n' >"$tmp/android/key.properties"
printf 'example\n' >"$tmp/android/key.properties.example"
printf 'fake-jks\n' >"$tmp/upload-keystore.jks"
printf 'fake\n' >"$tmp/android/debug.keystore"
printf '{"project_id":"secret"}\n' >"$tmp/android/app/google-services.json"
printf 'keep\n' >"$tmp/assets/logo.png"
printf 'keep\n' >"$tmp/README.md"
printf 'name: private\n' >"$tmp/.github/workflows/mirror-public.yml"
printf 'safe\n' >"$tmp/upload_certificate.pem"

"$PREPARE" "$tmp"

test ! -e "$tmp/android/key.properties"
test ! -e "$tmp/upload-keystore.jks"
test ! -e "$tmp/android/debug.keystore"
test ! -e "$tmp/android/app/google-services.json"
test -f "$tmp/android/key.properties.example"
test -f "$tmp/assets/logo.png"
test -f "$tmp/README.md"
test -f "$tmp/upload_certificate.pem"
# Workflows are excluded at rsync time, not by prepare; prepare leaves them alone.
test -f "$tmp/.github/workflows/mirror-public.yml"

# Re-inject a secret after prepare would be a workflow bug; the checker must fail.
printf 'leak\n' >"$tmp/sneaky.jks"
if "$PREPARE" --check-only "$tmp"; then
  echo "expected check-only to fail when .jks remains" >&2
  exit 1
fi
rm -f "$tmp/sneaky.jks"

printf '{"project_id":"secret"}\n' >"$tmp/android/app/google-services.json"
if "$PREPARE" --check-only "$tmp"; then
  echo "expected check-only to fail when google-services.json remains" >&2
  exit 1
fi

echo "mirror_public_prepare_test: ok"
