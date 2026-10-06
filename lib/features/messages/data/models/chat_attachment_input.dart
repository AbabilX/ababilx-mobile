import 'package:equatable/equatable.dart';

import '../../../attachments/crypto/attachment_secret.dart';

class ChatAttachmentInput extends Equatable {
  const ChatAttachmentInput({
    required this.fileUrl,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.viewSeconds,
    this.noSave = false,
    this.secret,
    this.seal,
  });

  final String fileUrl;
  final String fileName;
  final String contentType;
  final int sizeBytes;

  /// The privacy-mode send sheet's choice (see [ChatMessageAttachment]).
  /// Travels with the attachment so the outbox keeps it across a retry; the
  /// API lifts it to the message's `media_policy`.
  final int? viewSeconds;
  final bool noSave;

  /// Set when the upload was encrypted on this device (server 0168):
  /// [fileUrl] then holds ciphertext, and this is its key. [fileName],
  /// [contentType] and [sizeBytes] stay the real ones — the pending bubble
  /// draws from them — and never reach the server; see [toWire].
  final AttachmentSecret? secret;

  /// [secret] sealed under the conversation key for one send attempt. Never
  /// stored: a retry seals again, under whatever key is current by then.
  final SealedAttachmentMeta? seal;

  bool get restricted => viewSeconds != null || noSave;

  ChatAttachmentInput withSecret(AttachmentSecret secret) =>
      _copy(secret: secret, seal: seal);

  ChatAttachmentInput withSeal(SealedAttachmentMeta? seal) =>
      _copy(secret: secret, seal: seal);

  ChatAttachmentInput _copy({
    required AttachmentSecret? secret,
    required SealedAttachmentMeta? seal,
  }) => ChatAttachmentInput(
    fileUrl: fileUrl,
    fileName: fileName,
    contentType: contentType,
    sizeBytes: sizeBytes,
    viewSeconds: viewSeconds,
    noSave: noSave,
    secret: secret,
    seal: seal,
  );

  ChatAttachmentInput withPolicy({int? viewSeconds, required bool noSave}) =>
      ChatAttachmentInput(
        fileUrl: fileUrl,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: sizeBytes,
        viewSeconds: viewSeconds,
        noSave: noSave || viewSeconds != null,
        secret: secret,
        seal: seal,
      );

  factory ChatAttachmentInput.fromJson(Map<String, dynamic> json) =>
      ChatAttachmentInput(
        fileUrl: json['file_url'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        sizeBytes: json['size_bytes'] as int? ?? 0,
        viewSeconds: (json['view_seconds'] as num?)?.toInt(),
        noSave: json['no_save'] as bool? ?? false,
        secret: json['secret'] is Map
            ? AttachmentSecret.fromJson(
                Map<String, dynamic>.from(json['secret'] as Map),
              )
            : null,
      );

  /// **Local storage only** — the send outbox, so a send a kill interrupted
  /// can still be finished. It carries the file key; what goes to the server
  /// is [toWire].
  Map<String, dynamic> toJson() => {
    'file_url': fileUrl,
    'file_name': fileName,
    'content_type': contentType,
    'size_bytes': sizeBytes,
    'view_seconds': ?viewSeconds,
    if (noSave) 'no_save': true,
    'secret': ?secret?.toJson(),
  };

  /// The attachment as the send API takes it.
  ///
  /// An encrypted upload goes out with the kind of file and the ciphertext's
  /// size, plus its key sealed under the conversation key ([seal]). Without a
  /// seal there is no way to hand the receiver the key, so this throws rather
  /// than send a file nobody could ever open.
  Map<String, dynamic> toWire() {
    final secret = this.secret;
    final seal = this.seal;
    if (secret == null) {
      return {
        'file_url': fileUrl,
        'file_name': fileName,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      };
    }
    if (seal == null) {
      throw StateError('An encrypted file needs a secure chat');
    }
    return {
      'file_url': fileUrl,
      'file_name': secret.wireName,
      'content_type': secret.wireType,
      'size_bytes': secret.cipherSize,
      'enc_meta': seal.encMeta,
      'enc_nonce': seal.encNonce,
    };
  }

  @override
  List<Object?> get props => [fileUrl];
}
