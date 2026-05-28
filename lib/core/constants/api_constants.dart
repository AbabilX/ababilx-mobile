/// Base URL for the AbabilX backend.
/// Change to production URL for release builds.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://api.ababilx.cloud';

  // Auth
  static const String mobileGoogleAuth = '/auth/google/mobile';

  // User
  static const String me = '/api/me';

  // Rules
  static const String rules = '/api/rules';
  static String ruleById(String id) => '/api/rules/$id';
  static String rulePreview(String id) => '/api/rules/$id/preview';
  static String ruleTrigger(String id) => '/api/rules/$id/trigger';
  static String ruleMessages(String id) => '/api/rules/$id/messages';
  static String ruleMessageById(String ruleId, String msgId) =>
      '/api/rules/$ruleId/messages/$msgId';
  static String ruleOverride(String id) => '/api/rules/$id/override-message';

  // Slack
  static const String slackChannels = '/api/slack/channels';
  static const String slackDisconnect = '/api/slack/disconnect';

  // GitHub Repos
  static const String githubRepos = '/api/repos';
  static String repoBranches(String owner, String repo) =>
      '/api/repos/$owner/$repo/branches';

  // Activity
  static const String weeklyActivity = '/api/activity/weekly';

  // Auto-commit jobs
  static const String jobs = '/api/auto-commits';
  static String jobById(String id) => '/api/auto-commits/$id';

  // Devices (FCM)
  static const String devices = '/api/devices';
}

/// Secure storage keys.
class StorageKeys {
  StorageKeys._();

  static const String jwt = 'ababilx_jwt';
  static const String fcmToken = 'ababilx_fcm_token';
}

/// Notification channel config.
class NotificationChannels {
  NotificationChannels._();

  static const String standupId = 'standup_alerts';
  static const String standupName = 'Standup Alerts';
  static const String standupDesc =
      'Pre-send notifications before your standup fires';
}
