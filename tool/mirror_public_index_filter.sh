#!/bin/sh
# Drop signing material and private notes from the index of one commit.
# Called by git filter-branch. Authors and other files are left untouched.
git rm -r --cached --ignore-unmatch \
  android/key.properties \
  upload-keystore.jks \
  android/app/google-services.json \
  ios/Runner/GoogleService-Info.plist \
  upload_certificate.pem \
  plan.md \
  PLAY_STORE_WHATS_NEW.txt \
  PATHS_TO_REMOVE_BEFORE_PUBLIC.txt \
  docs/legal-audit \
  .github/workflows \
  .env \
  .env.local \
  >/dev/null 2>&1 || true

list="$(mktemp)"
git ls-files -z >"$list"
while IFS= read -r -d '' path; do
  case "$path" in
    *.pem | *.jks | *.keystore | *.p8 | docs/legal-audit/* | .github/workflows/* | docs/audits/*.md | tool/audit/*.md | .env | .env.local)
      git rm -r --cached --ignore-unmatch -- "$path" >/dev/null 2>&1 || true
      ;;
    key.properties | */key.properties)
      git rm -r --cached --ignore-unmatch -- "$path" >/dev/null 2>&1 || true
      ;;
  esac
done <"$list"
rm -f "$list"
