# Vendored libsqlite3.so

`package:sqlite3` (used by Drift) is configured with `hooks: user_defines: sqlite3: source: system`
in `pubspec.yaml` — it does a plain `dlopen("libsqlite3.so")` and expects the app to already
carry that library. Flutter's Android build backend does not yet request code assets, so
`package:sqlite3`'s own build hook can't bundle it automatically on this platform, and
`sqlite3_flutter_libs` (which used to) is a no-op as of 0.6.0. So the `.so` for each ABI is
vendored here by hand; Gradle picks up anything under `jniLibs/<abi>/` automatically.

These three files came straight from `package:sqlite3`'s own GitHub release assets (the same
binaries its build hook would have downloaded), sha256-verified against the hashes baked into
the package itself:

```
https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<version>/libsqlite3.<arch>.android.so
```

| ABI          | source arch | sha256 (must match `asset_hashes.dart` in the pub-cache'd sqlite3 package) |
| ------------ | ----------- | --------------------------------------------------------------------------- |
| arm64-v8a    | arm64       | e99515af1d7119fb61843ae5e597344e7f258563de3a7e5a3869f627aab2887b            |
| armeabi-v7a  | arm         | 6c1b8dffc1ddefaf02e771711491410bc3ab1db858d3d23d2925e0b2cd691b93            |
| x86_64       | x64         | e5a2d46ac5e11f471e1aaedfd364f54c7961a6900432d289ea3f5781bcaaf4cd            |

Current version: `sqlite3` package `3.5.0` (see `pubspec.lock`).

## Updating

When the `sqlite3` package version bumps in `pubspec.lock`, re-run for each arch
(`arm64`, `arm`, `x64`) and replace the matching file here:

```bash
curl -sL \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<new-version>/libsqlite3.<arch>.android.so" \
  -o libsqlite3.so
shasum -a 256 libsqlite3.so   # compare against ~/.pub-cache/hosted/pub.dev/sqlite3-<new-version>/lib/src/hook/asset_hashes.dart
```

If Flutter ever adds real Android code-assets support, this whole directory (and the
`source: system` config in `pubspec.yaml`) can be deleted in favor of `source: sqlite3`
(the hooks download path), which is what was originally attempted here before it was found
not to work on Flutter 3.44.8.
