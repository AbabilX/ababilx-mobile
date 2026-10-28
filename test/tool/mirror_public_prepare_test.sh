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
mkdir -p "$tmp/docs/legal-audit" "$tmp/docs/audits" "$tmp/tool/audit"
printf 'keep\n' >"$tmp/assets/logo.png"
printf 'keep\n' >"$tmp/README.md"
printf 'keep\n' >"$tmp/CLAUDE.md"
printf 'keep\n' >"$tmp/docs/RELEASE_SIGNING.md"
printf 'keep\n' >"$tmp/tool/audit/media_scroll_repro_test.dart"
printf 'name: private\n' >"$tmp/.github/workflows/mirror-public.yml"
printf 'cert\n' >"$tmp/upload_certificate.pem"
printf 'scratch\n' >"$tmp/plan.md"
printf 'store\n' >"$tmp/PLAY_STORE_WHATS_NEW.txt"
printf 'checklist\n' >"$tmp/PATHS_TO_REMOVE_BEFORE_PUBLIC.txt"
printf 'audit\n' >"$tmp/docs/legal-audit/LICENSE_AUDIT_REPORT.md"
printf 'audit\n' >"$tmp/docs/audits/2026-09-10-mobile-media-scroll.md"
printf 'audit\n' >"$tmp/tool/audit/GROUP_CALL_HOME_RESUME_AUDIT.md"

"$PREPARE" "$tmp"

test ! -e "$tmp/android/key.properties"
test ! -e "$tmp/upload-keystore.jks"
test ! -e "$tmp/android/debug.keystore"
test ! -e "$tmp/android/app/google-services.json"
test ! -e "$tmp/upload_certificate.pem"
test ! -e "$tmp/plan.md"
test ! -e "$tmp/PLAY_STORE_WHATS_NEW.txt"
test ! -e "$tmp/PATHS_TO_REMOVE_BEFORE_PUBLIC.txt"
test ! -e "$tmp/docs/legal-audit"
test ! -e "$tmp/docs/audits/2026-09-10-mobile-media-scroll.md"
test ! -e "$tmp/tool/audit/GROUP_CALL_HOME_RESUME_AUDIT.md"
test -f "$tmp/android/key.properties.example"
test -f "$tmp/assets/logo.png"
test -f "$tmp/README.md"
test -f "$tmp/CLAUDE.md"
test -f "$tmp/docs/RELEASE_SIGNING.md"
test -f "$tmp/tool/audit/media_scroll_repro_test.dart"
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
rm -f "$tmp/android/app/google-services.json"

printf 'cert\n' >"$tmp/upload_certificate.pem"
if "$PREPARE" --check-only "$tmp"; then
  echo "expected check-only to fail when a .pem remains" >&2
  exit 1
fi

echo "mirror_public_prepare_test: ok"
