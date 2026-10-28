#!/usr/bin/env bash
# Copy a repository and rewrite every commit so authors, messages, and file
# diffs stay, while signing material and private notes are gone from history.
# Usage: mirror_public_history.sh <source-repo> <dest-dir>
set -euo pipefail

usage() {
  echo "usage: $0 <source-repo> <dest-dir>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
src="$(cd "$1" && pwd)"
dest="$2"
root="$(cd "$(dirname "$0")" && pwd)"
filter="$root/mirror_public_index_filter.sh"

rm -rf "$dest"
# --no-hardlinks: a local clone otherwise shares object files with the source.
# Pruning the rewritten copy would delete those objects from the private repo.
git clone --no-hardlinks --quiet "$src" "$dest"

# A clone keeps the source commits on refs/remotes/origin. Those refs are not
# rewritten, so a secret removed from main would stay reachable through them.
while read -r name; do
  git -C "$dest" remote remove "$name"
done < <(git -C "$dest" remote)

FILTER_BRANCH_SQUELCH_WARNING=1 \
  git -C "$dest" filter-branch --force \
    --index-filter "$filter" \
    --tag-name-filter cat \
    -- --branches

while read -r ref; do
  git -C "$dest" update-ref -d "$ref"
done < <(git -C "$dest" for-each-ref --format='%(refname)' refs/original refs/remotes)
git -C "$dest" reflog expire --expire=now --all
git -C "$dest" gc --prune=now --quiet

if git -C "$dest" rev-list --all --objects | awk '{print $2}' | grep -E '(^|/)(upload-keystore\.jks|google-services\.json|GoogleService-Info\.plist|upload_certificate\.pem|PATHS_TO_REMOVE_BEFORE_PUBLIC\.txt|key\.properties)$|\.pem$|\.jks$|\.keystore$|\.p8$|(^|/)\.github/workflows/'; then
  echo "refusing public mirror: stripped path is still reachable" >&2
  exit 1
fi

echo "mirror_public_history: rewritten ($dest)"
