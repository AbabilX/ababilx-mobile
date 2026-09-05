part of 'message_vault.dart';

/// Unlocking this device with the recovery code its owner saved.
///
/// The code is turned into a key here and used here; it is never sent anywhere.
/// What the server handed over was ciphertext it cannot open, so a correct code
/// is the only thing in the world that opens it — and every message the account
/// has ever received decrypts, because the identity is the same one.
extension MessageVaultRecover on MessageVault {
  Future<void> unlockWithRecoveryCode(String input) async {
    final code = RecoveryKey.parse(input);
    if (code == null) {
      throw ArgumentError('That is not a complete recovery code');
    }
    final status = await _repo.getE2eeVault();
    if (status['exists'] != true) {
      throw StateError('This account has no message identity yet');
    }
    final vault = Map<String, dynamic>.from(status['vault'] as Map);
    final recovery = vault['recovery'];
    if (recovery is! Map) {
      throw StateError('This account has no recovery code set up');
    }
    Map<String, dynamic> privateJwk;
    try {
      privateJwk = await RecoveryKey.unwrap(
        RecoveryVault.fromJson(Map<String, dynamic>.from(recovery)),
        code,
      );
    } catch (_) {
      // A wrong code and a corrupt blob fail the same AES-GCM tag check, and
      // the difference is of no use to the person holding the code.
      throw StateError('That recovery code is not right');
    }
    await _adopt(
      _identityFromJwk(privateJwk),
      Map<String, dynamic>.from(vault['public_key'] as Map),
    );
  }

  /// Issues a new recovery code for the same identity.
  ///
  /// This is the only way to see a code again: the old one was never stored,
  /// here or on the server, so it can only be replaced. Re-wrapping the same
  /// private key keeps every message readable and retires the previous code the
  /// moment this returns.
  Future<String> regenerateRecoveryCode() async {
    final identity = _identity;
    final publicJwk = _publicJwk;
    if (identity == null || publicJwk == null) {
      throw StateError('Unlock messages on this device first');
    }
    final code = RecoveryKey.generateCode();
    final vault = await RecoveryKey.wrap(
      _privateJwkFromIdentity(identity),
      code,
    );
    await _repo.putE2eeRecoveryVault(publicJwk, vault.toJson());
    return RecoveryKey.format(code);
  }
}
