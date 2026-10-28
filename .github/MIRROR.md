# Public mirror

Private `main` → public [`AbabilX/ababilx-mobile`](https://github.com/AbabilX/ababilx-mobile).

## Behaviour

- Trigger: push to `main`, or manual `workflow_dispatch`
- Publishes the **current tree only** (updates public `main`)
- Strips Android signing material via `tool/mirror_public_prepare.sh`
- Does **not** copy private git history (historical keystore commits must never become public)

Org policy disables deploy keys on the public repo, so the Action authenticates with a PAT.

## Secret

Private repo Actions secret:

| Name | Value |
| --- | --- |
| `PUBLIC_MIRROR_TOKEN` | Fine-grained PAT: resource `AbabilX/ababilx-mobile`, permission **Contents: Read and write** |

Create at https://github.com/settings/personal-access-tokens/new

## Local check

```bash
./test/tool/mirror_public_prepare_test.sh
```
