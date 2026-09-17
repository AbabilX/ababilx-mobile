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
  // Both Go senders' channelFor() can return this id. Ringing pushes are sent
  // data-only today and short-circuit before that switch, so nothing reaches
  // it in practice — but a channel id no channel answers to makes FCM quietly
  // demote the notification to `general`, and that is not a trap worth
  // leaving armed. The tone itself never comes from here: `call_ringer` owns
  // it (see features/calls/CLAUDE.md).
  // Ghost Chat invites. Its own channel so a user can silence invites
  // without silencing chat — and the reverse.
  AndroidNotificationChannel(
    'ghost_chat',
    'Ghost Chat',
    description: 'Ghost Chat invites',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'voice_calls',
    'Voice calls',
    description: 'Incoming and ongoing voice calls',
    importance: Importance.max,
  ),
];
