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
    'general',
    'General',
    description: 'General AbabilX alerts',
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

/// Channels earlier builds created for workspace features (Wall, Board,
/// standup, team updates, the AI assistant), deleted on init so Android's
/// notification settings list only what this chat app still posts.
const retiredNotificationChannelIds = [
  'board',
  'wall',
  'standup_alerts',
  'team_updates',
  'ai_assistant',
];

/// Workspace pushes the server still sends to every device; this app is chat
/// only and has no screen for them.
bool isWorkspacePush(String? type) => const {
  'wall_mention',
  'wall_comment',
  'wall_reply',
  'wall_category_request',
  'kanban_assignment',
  'kanban_mention',
  'kanban_comment',
  'kanban_watcher',
  'board_notes',
  'board_notes_mention',
  'pre_send_review',
  'ai_assistant',
  'team_member_left',
}.contains(type);
