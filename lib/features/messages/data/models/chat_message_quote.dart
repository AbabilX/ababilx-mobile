import 'package:equatable/equatable.dart';

/// The message a quoted reply answers, as the server resolves it.
///
/// Not a snapshot: the server joins the original row at read time, so an edit
/// to the original updates the quote and deleting it leaves [deleted] set. In a
/// DM the original's text is ciphertext, so [body] arrives empty and
/// [encryptedBody]/[encryptionNonce]/[encryptionKeyVersion] carry it instead —
/// `MessageVault` fills [body] in after decrypting, and `messageRow` blanks it
/// again before the message is written to disk.
///
/// [userId] is the *quoted* sender, not the quoting one. The DM cipher binds
/// the sender into its AAD, so decrypting with the wrong id fails.
class ChatMessageQuote extends Equatable {
  const ChatMessageQuote({
    required this.messageId,
    this.userId = '',
    this.userName,
    this.body = '',
    this.encryptedBody,
    this.encryptionNonce,
    this.encryptionKeyVersion,
    this.attachmentType,
    this.deleted = false,
  });

  final String messageId;
  final String userId;
  final String? userName;
  final String body;
  final String? encryptedBody;
  final String? encryptionNonce;
  final int? encryptionKeyVersion;
  final String? attachmentType;
  final bool deleted;

  bool get isEncrypted =>
      (encryptedBody?.isNotEmpty ?? false) &&
      (encryptionNonce?.isNotEmpty ?? false);

  bool get isImage => attachmentType?.startsWith('image/') ?? false;
  bool get isVideo => attachmentType?.startsWith('video/') ?? false;
  bool get isAudio => attachmentType?.startsWith('audio/') ?? false;

  factory ChatMessageQuote.fromJson(Map<String, dynamic> json) =>
      ChatMessageQuote(
        messageId: json['message_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        userName: json['user_name'] as String?,
        body: json['body'] as String? ?? '',
        encryptedBody: json['encrypted_body'] as String?,
        encryptionNonce: json['encryption_nonce'] as String?,
        encryptionKeyVersion: (json['encryption_key_version'] as num?)?.toInt(),
        attachmentType: json['attachment_type'] as String?,
        deleted: json['deleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'user_id': userId,
    'user_name': ?userName,
    'body': body,
    'encrypted_body': ?encryptedBody,
    'encryption_nonce': ?encryptionNonce,
    'encryption_key_version': ?encryptionKeyVersion,
    'attachment_type': ?attachmentType,
    'deleted': deleted,
  };

  ChatMessageQuote copyWith({String? body}) => ChatMessageQuote(
    messageId: messageId,
    userId: userId,
    userName: userName,
    body: body ?? this.body,
    encryptedBody: encryptedBody,
    encryptionNonce: encryptionNonce,
    encryptionKeyVersion: encryptionKeyVersion,
    attachmentType: attachmentType,
    deleted: deleted,
  );

  @override
  List<Object?> get props => [
    messageId,
    userId,
    userName,
    body,
    encryptedBody,
    encryptionNonce,
    encryptionKeyVersion,
    attachmentType,
    deleted,
  ];
}
