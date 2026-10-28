#!/usr/bin/env bash
# Sanitize a checkout before publishing to the public AbabilX mirror.
# Strips paths listed in PATHS_TO_REMOVE_BEFORE_PUBLIC.txt plus keystore blobs.
set -euo pipefail

usage() {
  echo "usage: $0 [--check-only] <tree-root>" >&2
  exit 2
}

check_only=0
if [[ "${1:-}" == "--check-only" ]]; then
  check_only=1
  shift
fi

[[ $# -eq 1 ]] || usage
root="$(cd "$1" && pwd)"

# Must never ship to the public mirror (see PATHS_TO_REMOVE_BEFORE_PUBLIC.txt).
FORBIDDEN_PATHS=(
  android/key.properties
  upload-keystore.jks
  android/app/google-services.json
)

strip_secrets() {
  local dir="$1"
  local rel
  for rel in "${FORBIDDEN_PATHS[@]}"; do
    rm -f "$dir/$rel"
  done
  # Any other keystore blobs that may appear under the tree.
  find "$dir" \( -name '*.jks' -o -name '*.keystore' \) -type f -print -delete
  # Never publish local IDE / secret env copies.
  rm -f "$dir/.env" "$dir/.env.local"
  find "$dir" -name 'key.properties' -type f ! -name 'key.properties.example' -print -delete
}

assert_clean() {
  local dir="$1"
  local bad=0
  local rel
  for rel in "${FORBIDDEN_PATHS[@]}"; do
    if [[ -e "$dir/$rel" ]]; then
      echo "refusing public mirror: $rel still present" >&2
      bad=1
    fi
  done
  while IFS= read -r -d '' f; do
    echo "refusing public mirror: signing blob still present: ${f#"$dir"/}" >&2
    bad=1
  done < <(find "$dir" \( -name '*.jks' -o -name '*.keystore' \) -type f -print0 2>/dev/null)
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    if [[ "$base" != "key.properties.example" ]]; then
      echo "refusing public mirror: key.properties still present: ${f#"$dir"/}" >&2
      bad=1
    fi
  done < <(find "$dir" -name 'key.properties' -type f -print0 2>/dev/null)
  return "$bad"
}

if [[ "$check_only" -eq 0 ]]; then
  strip_secrets "$root"
fi
assert_clean "$root"
echo "mirror_public_prepare: tree is clean for public publish ($root)"
