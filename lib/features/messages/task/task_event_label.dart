import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../chat_utils.dart';
import '../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'task_card_data.dart';
import 'task_strings.dart';

const _titleLimit = 40;

/// The timeline line for a task change — "You marked "Fix login" as Done" —
/// or null when [message] is some other update.
///
/// The server's line cannot name the task: its title is sealed. This side
/// holds the card, so it looks the title up in the open timeline and says
/// "a task" when the card is not loaded.
String? taskEventLabel(
  BuildContext context,
  ChatMessage message,
  String currentUserId,
) {
  final meta = message.meta;
  final event = meta?['event'];
  if (event != 'task_status_changed' && event != 'task_priority_changed') {
    return null;
  }
  var language = 'en';
  var title = '';
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    language = container.read(appLanguageProvider);
    final taskId = meta?['message_id'];
    final feed = container
        .read(chatProvider)
        .feeds[feedKey(message.conversationId)];
    for (final candidate in feed?.messages ?? const <ChatMessage>[]) {
      if (candidate.id != taskId) continue;
      title = taskText(candidate).title;
      break;
    }
  } catch (_) {
    // No provider scope above this row: the plain line still reads.
  }
  if (title.length > _titleLimit) {
    title = '${title.substring(0, _titleLimit).trimRight()}…';
  }
  final strings = TaskStrings.of(language);
  final name = (meta?['actor_name'] as String?)?.trim() ?? '';
  final actor = meta?['actor_id'] == currentUserId
      ? (strings.bangla ? 'আপনি' : 'You')
      : (name.isEmpty ? (strings.bangla ? 'কেউ' : 'Someone') : name);
  final value = meta?['value'];
  return event == 'task_status_changed'
      ? strings.statusChanged(actor, TaskStatus.parse(value), title)
      : strings.priorityChanged(actor, TaskPriority.parse(value), title);
}
