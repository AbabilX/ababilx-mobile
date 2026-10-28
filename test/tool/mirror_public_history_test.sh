#!/usr/bin/env bash
# The public mirror keeps each commit's author and file diff. Signing
# material is removed from every commit, not only from the latest tree.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HISTORY="$ROOT/tool/mirror_public_history.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

src="$tmp/src"
mkdir -p "$src/android" "$src/.github/workflows" "$src/docs/audits"
git -C "$src" init -b main >/dev/null
git -C "$src" config user.name "Test"
git -C "$src" config user.email "test@example.com"

printf 'hello\n' >"$src/README.md"
printf 'storePassword=secret\n' >"$src/android/key.properties"
printf 'example\n' >"$src/android/key.properties.example"
printf 'cert\n' >"$src/upload_certificate.pem"
printf 'name: private\n' >"$src/.github/workflows/mirror-public.yml"
printf 'audit\n' >"$src/docs/audits/note.md"
git -C "$src" add .
GIT_AUTHOR_NAME=Alice GIT_AUTHOR_EMAIL=alice@example.com \
GIT_COMMITTER_NAME=Alice GIT_COMMITTER_EMAIL=alice@example.com \
  git -C "$src" commit -q -m "Add the readme and a key"

printf 'hello world\n' >"$src/README.md"
git -C "$src" add README.md
GIT_AUTHOR_NAME=Bob GIT_AUTHOR_EMAIL=bob@example.com \
GIT_COMMITTER_NAME=Bob GIT_COMMITTER_EMAIL=bob@example.com \
  git -C "$src" commit -q -m "Rewrite the readme"

"$HISTORY" "$src" "$tmp/public"

pub="$tmp/public"
test "$(git -C "$pub" rev-list --count HEAD)" -eq 2
test "$(git -C "$pub" log --format='%an <%ae>' --reverse | head -1)" = "Alice <alice@example.com>"
test "$(git -C "$pub" log --format='%an <%ae>' -1)" = "Bob <bob@example.com>"
test "$(git -C "$pub" log --format='%cn <%ce>' -1)" = "Bob <bob@example.com>"
test "$(git -C "$pub" show HEAD:README.md)" = "hello world"
test "$(git -C "$pub" show 'HEAD~1:README.md')" = "hello"
test "$(git -C "$pub" show HEAD:android/key.properties.example)" = "example"
test -z "$(git -C "$pub" rev-list --all --objects | awk '{print $2}' | grep -E '(^|/)(key\.properties|upload_certificate\.pem|mirror-public\.yml|note\.md)$' || true)"

"$HISTORY" "$src" "$tmp/public-again"
test "$(git -C "$pub" rev-parse HEAD)" = "$(git -C "$tmp/public-again" rev-parse HEAD)"

echo "mirror_public_history_test: ok"
