import 'models/chat_attachment_input.dart';

/// The body of a send request. One builder for a message sent now and one
/// stored to be sent later (server 0171): the server replays the stored body
/// through the ordinary send path, so the two must be the same shape.
Map<String, dynamic> chatSendBody({
  required String clientMessageId,
  required String body,
  String? encryptedBody,
  String? encryptionNonce,
  int? encryptionVersion,
  int? encryptionKeyVersion,
  String? parentId,
  String? quotedMessageId,
  List<ChatAttachmentInput> attachments = const [],
  List<String> mentionedUserIds = const [],
  String? taskPriority,
}) => {
  'client_message_id': clientMessageId,
  'body': body,
  'encrypted_body': ?encryptedBody,
  'encryption_nonce': ?encryptionNonce,
  'encryption_version': ?encryptionVersion,
  'encryption_key_version': ?encryptionKeyVersion,
  'parent_id': ?parentId,
  'quoted_message_id': ?quotedMessageId,
  if (attachments.isNotEmpty)
    'attachments': attachments.map((a) => a.toWire()).toList(),
  if (mentionedUserIds.isNotEmpty) 'mentioned_user_ids': mentionedUserIds,
  'media_policy': ?chatMediaPolicy(attachments),
  // Makes the message a task card (server 0169).
  if (taskPriority != null) 'task': {'priority': taskPriority},
};

/// The privacy-mode sheet's choice travels on each attachment; the API takes
/// ONE policy per message (the sheet applies the same choice to all of
/// them). Null when nothing was restricted.
Map<String, dynamic>? chatMediaPolicy(List<ChatAttachmentInput> attachments) {
  for (final a in attachments) {
    if (!a.restricted) continue;
    return {'view_seconds': a.viewSeconds, 'allow_save': !a.noSave};
  }
  return null;
}
