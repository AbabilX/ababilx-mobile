#!/usr/bin/env bash
# Sanitize a checkout before publishing to the public AbabilX mirror.
# Strips Android upload signing material that must never leave the private repo.
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

strip_secrets() {
  local dir="$1"
  # Exact private signing inputs (tracked today on private main).
  rm -f "$dir/android/key.properties" "$dir/upload-keystore.jks"
  # Any other keystore blobs that may appear under the tree.
  find "$dir" \( -name '*.jks' -o -name '*.keystore' \) -type f -print -delete
  # Never publish local IDE / secret env copies.
  rm -f "$dir/.env" "$dir/.env.local"
  find "$dir" -name 'key.properties' -type f ! -name 'key.properties.example' -print -delete
}

assert_clean() {
  local dir="$1"
  local bad=0
  if [[ -e "$dir/android/key.properties" ]]; then
    echo "refusing public mirror: android/key.properties still present" >&2
    bad=1
  fi
  if [[ -e "$dir/upload-keystore.jks" ]]; then
    echo "refusing public mirror: upload-keystore.jks still present" >&2
    bad=1
  fi
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
