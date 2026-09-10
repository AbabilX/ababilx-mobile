part of 'message_vault.dart';

/// Unlocking this device with the recovery code its owner saved.
///
/// The code is turned into a key here and used here; it is never sent anywhere.
/// What the server handed over was ciphertext it cannot open, so a correct code
/// is the only thing in the world that opens it — and available messages can decrypt under the restored identity.
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
    final publicJwk = Map<String, dynamic>.from(vault['public_key'] as Map);
    if (privateJwk['x'] != publicJwk['x'] ||
        privateJwk['y'] != publicJwk['y']) {
      throw StateError('The recovery backup does not match this account');
    }
    await _adopt(_identityFromJwk(privateJwk), publicJwk);
    await _storeRecoveryCode(publicJwk, RecoveryKey.format(code));
  }

  /// Explicit code creation from Settings when this phone has no saved code.
  /// Rewraps the same identity and saves the new code only on this phone.
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
    await _publishRecoveryCode(publicJwk, code, vault);
    return RecoveryKey.format(code);
  }
}
