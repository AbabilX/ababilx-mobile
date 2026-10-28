# Public mirror

Private `main` → public [`AbabilX/ababilx-mobile`](https://github.com/AbabilX/ababilx-mobile).

## Behaviour

- Trigger: push to `main`, or manual `workflow_dispatch`
- Publishes the **current tree only** (updates public `main`)
- Strips paths from `PATHS_TO_REMOVE_BEFORE_PUBLIC.txt` via `tool/mirror_public_prepare.sh`
  (`android/key.properties`, `upload-keystore.jks`, `android/app/google-services.json`, plus any `*.jks` / `*.keystore`)
- Does **not** copy private git history
- Does **not** copy `.github/workflows/` (avoids GitHub’s “OAuth App needs `workflow` scope” rejection, and keeps public CI separate)

`upload_certificate.pem` is treated as public-safe (per `PATHS_TO_REMOVE_BEFORE_PUBLIC.txt`).

## Secret

Private repo Actions secret:

| Name | Value |
| --- | --- |
| `PUBLIC_MIRROR_TOKEN` | Fine-grained PAT: resource `AbabilX/ababilx-mobile`, permission **Contents: Read and write** |

No `workflow` scope is required while workflows are excluded from the publish set.

## Local check

```bash
./test/tool/mirror_public_prepare_test.sh
```
