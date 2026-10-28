# Android release signing

The upload keystore and its passwords are private release credentials. Keep
`android/key.properties` and all `.jks` / `.keystore` files outside version
control. Ignore rules alone do not protect files already tracked by Git.

For local releases, copy `android/key.properties.example` to
`android/key.properties`, set private values, and point `storeFile` at the
private keystore. Gradle resolves relative paths from `android/app`; an absolute
path is also supported. Existing release builds require this configuration and
never fall back to debug signing.

For CI, provision the keystore and properties from the CI secret store into
temporary private files before the release build. Do not echo their contents,
upload them as artifacts, or commit them. Remove temporary files after use.
Run `python3 tool/security/check_signing_material.py` before committing; the
same guard runs on pull requests and pushes to main.

## Follow-up for the previously committed upload key (issue #10)

Removing files from the current tree does not revoke the key or remove it from
existing Git history and clones. Keep issue #10 open until a release owner has:

- Identified the exposed certificate's role in Play Console. An upload key and
  the app signing key are distinct when Play App Signing is enabled.
- Completed the appropriate upload key reset/replacement process and moved
  local/CI release configuration to the replacement private key.
- Verified a release signed with the replacement configuration is accepted by
  the release service.
- Coordinated history cleanup and treatment of retained clones, forks, caches,
  and artifacts. History rewriting must be planned with repository collaborators;
  this repository cleanup does not perform a force push or erase old copies.

Do not paste passwords, private keys, or keystore contents into issue comments.
