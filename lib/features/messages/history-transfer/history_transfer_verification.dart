import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Six digits over the destination's ephemeral public key, shown on both
/// screens so the user can compare them by eye.
///
/// **Byte-identical to the device-link code** (`MessageVaultLink.
/// linkVerificationCode`) and to web's `device-link.ts`, on purpose: it is the
/// same question — "is the key I am sealing to the one on that screen?" — and
/// two derivations for one question is how the numbers end up disagreeing on
/// different platforms and the check becomes worse than having none.
///
/// The phone derives this from the key it read off the CAMERA, never from
/// anything the server returned. A code the server computed could not detect
/// the substitution this exists to detect.
Future<String> historyTransferVerificationCode(
  Map<String, dynamic> publicJwk,
) async {
  final digest = await Sha256().hash(
    utf8.encode('${publicJwk['crv']}.${publicJwk['x']}.${publicJwk['y']}'),
  );
  final bytes = digest.bytes;
  final value = ((bytes[0] << 16) | (bytes[1] << 8) | bytes[2]) % 1000000;
  return value.toString().padLeft(6, '0');
}
