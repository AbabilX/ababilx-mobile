import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Every Android notification channel this app posts to.
///
/// Created by both isolates on init: a channel that does not exist yet makes
/// its notification silent, so the FCM background isolate cannot assume the app
/// ever ran.
const notificationChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    'chat',
    'Chat',
    description: 'Direct messages and mentions',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'board',
    'Board',
    description: 'Task assignments, comments and board notes',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'wall',
    'Wall',
    description: 'Team wall mentions, comments and replies',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'general',
    'General',
    description: 'General AbabilX alerts',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    'standup_alerts',
    'Standup alerts',
    description: 'Standup pre-send reminders',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'team_updates',
    'Team updates',
    description: 'Team membership and activity',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    'ai_assistant',
    'AI assistant',
    description: 'AI assistant alerts',
    importance: Importance.defaultImportance,
  ),
];
