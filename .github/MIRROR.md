# Public mirror

Private `main` → public [`AbabilX/ababilx-mobile`](https://github.com/AbabilX/ababilx-mobile).

## Behaviour

- Trigger: push to `main`, or manual `workflow_dispatch`
- Publishes **every commit on `main`**. Author, message, and file diff stay. GitHub contributors come from those authors.
- Rewrites each commit so these never ship: `android/key.properties`, `upload-keystore.jks`, `android/app/google-services.json`, `*.jks`, `*.keystore`, `*.pem`, `plan.md`, `PLAY_STORE_WHATS_NEW.txt`, `PATHS_TO_REMOVE_BEFORE_PUBLIC.txt`, `docs/legal-audit/`, and audit `*.md` under `docs/audits/` and `tool/audit/`.
- Does **not** publish `.github/workflows/` (the token has no `workflow` scope, and private CI stays here).
- Replaces public `main` when the histories differ. The old snapshot commits are not kept.

## Secret

Private repo Actions secret:

| Name | Value |
| --- | --- |
| `PUBLIC_MIRROR_TOKEN` | Fine-grained PAT: resource `AbabilX/ababilx-mobile`, permission **Contents: Read and write** |

No `workflow` scope is required while workflows are excluded from the publish set.

## Local check

```bash
./test/tool/mirror_public_prepare_test.sh
./test/tool/mirror_public_history_test.sh
```

The index filter is POSIX `sh`. GitHub's runner uses dash, which rejects `read -d`.
