/// The build this app was compiled as, written by hand at release time.
///
/// Bump both together with `version:` in pubspec.yaml (`5.2.9+30` is
/// [appVersionName] `5.2.9`, [appBuildNumber] `30`).
/// `test/core/app_version_test.dart` fails if they drift, because the update
/// check (`features/app-update/`) sends [appBuildNumber] to the server: a
/// stale number here would tell every phone it is out of date, or never.
const appVersionName = '5.5.0';
const appBuildNumber = 42;
