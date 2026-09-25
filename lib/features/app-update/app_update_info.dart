/// The server's answer to "is this build current?"
/// (`GET /v1/api/app/version`, ababilx-server migration 0158).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.updateAvailable,
    required this.updateRequired,
    required this.whatsNew,
    required this.storeUrl,
  });

  final String latestVersion;
  final int latestBuild;
  final bool updateAvailable;

  /// This build may not run: the app is blocked until it is updated.
  final bool updateRequired;

  /// Notes of the newest release only.
  final String whatsNew;

  /// Empty when the admin set none and the platform has no default.
  final String storeUrl;

  /// Reads the `data` object. Anything malformed reads as "no update", so a
  /// bad answer can never lock the app.
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final available = json['update_available'] == true;
    return AppUpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '',
      latestBuild: (json['latest_build'] as num?)?.toInt() ?? 0,
      updateAvailable: available,
      updateRequired: available && json['update_required'] == true,
      whatsNew: (json['whats_new'] as String? ?? '').trim(),
      storeUrl: json['store_url'] as String? ?? '',
    );
  }
}
