import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Routes the new device serves while it waits (TRANSFER_CHATS_PROTOCOL.md).
const transferPathIdentity = '/abx-transfer/v1/identity';
const transferPathStream = '/abx-transfer/v1/stream';
const transferPathStatus = '/abx-transfer/v1/status';

const _authInfo = 'ababilx-transfer-chats-auth-v1';

/// The bearer token every request carries: HMAC-SHA256 over a fixed label,
/// keyed by the code's secret. It travels in the clear on the Wi-Fi, so it
/// only keeps strangers from talking to the new device; it reveals nothing
/// of the secret that seals the stream.
Future<String> transferAuthToken(List<int> secret) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode(_authInfo),
    secretKey: SecretKey(secret),
  );
  return base64Url.encode(mac.bytes).replaceAll('=', '');
}

/// Constant time, so the token cannot be guessed a byte at a time.
bool sameTransferToken(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Where the new device is, as both sides report it.
enum TransferStep { waiting, receiving, importing, done, failed }

class TransferStatus {
  const TransferStatus({
    this.step = TransferStep.waiting,
    this.bytes = 0,
    this.messages = 0,
    this.files = 0,
    this.error = '',
  });

  final TransferStep step;

  /// Bytes of the stream received so far.
  final int bytes;

  /// Messages and files put into the new device's store so far.
  final int messages;
  final int files;

  /// A short code (`wrong_account`, `incomplete`, `no_space`, `failed`).
  final String error;

  TransferStatus copyWith({
    TransferStep? step,
    int? bytes,
    int? messages,
    int? files,
    String? error,
  }) => TransferStatus(
    step: step ?? this.step,
    bytes: bytes ?? this.bytes,
    messages: messages ?? this.messages,
    files: files ?? this.files,
    error: error ?? this.error,
  );

  Map<String, dynamic> toJson() => {
    'step': step.name,
    'bytes': bytes,
    'messages': messages,
    'files': files,
    'error': error,
  };

  factory TransferStatus.fromJson(Map<String, dynamic> json) {
    final name = json['step'];
    return TransferStatus(
      step: TransferStep.values.firstWhere(
        (s) => s.name == name,
        orElse: () => TransferStep.failed,
      ),
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      messages: (json['messages'] as num?)?.toInt() ?? 0,
      files: (json['files'] as num?)?.toInt() ?? 0,
      error: json['error'] as String? ?? '',
    );
  }
}
