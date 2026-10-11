import '../../../core/network/friendly_error.dart';
import '../tiptap_plain_text.dart';
import 'scheduled_message.dart';

/// Why a message could not be scheduled, moved or sent now.
String sendLaterErrorText(Object error) {
  if (isOfflineError(error)) return 'No connection. Try again.';
  return switch (serverErrorCode(error)) {
    'scheduled_limit' =>
      'You have the most scheduled messages allowed. Send or delete one first.',
    'invalid_send_at' =>
      'Pick a time at least a minute ahead and within 120 days.',
    'scheduled_not_in_private_chat' =>
      'Send later is off while private chat is on.',
    'scheduled_not_here' => 'Send later is not available in this chat.',
    'scheduled_no_timed_media' => 'A timed photo cannot be sent later.',
    'message_rate_limited' => 'Too many messages. Try again in a moment.',
    final code? => scheduledFailText(code),
    null => 'Could not do that. Try again.',
  };
}

/// Why the server did not send a scheduled message at its time.
String scheduledFailText(String reason) => switch (reason) {
  'not_a_member' => 'You are no longer in this chat.',
  'member_restricted' => 'An admin turned off sending for you.',
  'media_restricted' => 'This group no longer allows that kind of file.',
  'blocked' ||
  'connection_removed' ||
  'account_deleted' => 'You can no longer message this person.',
  'conversation_archived' ||
  'conversation_read_only' => 'This chat no longer takes messages.',
  'scheduled_not_in_private_chat' => 'Private chat was turned on.',
  'scheduled_gave_up' => 'The server could not send it.',
  'chat_key_rotation_required' ||
  'message encryption key unavailable' => 'Open your messages to send it.',
  _ => 'Not sent.',
};

/// One line for the list: the text, or what the message carries.
String scheduledPreview(ScheduledMessage row) {
  final opened = row.opened;
  final files = (row.request['attachments'] as List?)?.length ?? 0;
  final text = opened == null ? '' : tiptapToPreviewText(opened.body).trim();
  final sealed = row.request['encryption_version'] == 1;
  final unread =
      text.isEmpty ||
      text == 'Encrypted message' ||
      text == 'Unable to decrypt this message';
  if (!unread) return text;
  if (files == 1) return 'Attachment';
  if (files > 1) return '$files attachments';
  return sealed ? 'Encrypted message' : '';
}
