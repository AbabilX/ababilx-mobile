part of 'message_vault.dart';

/// Start fresh: a brand-new message identity for someone with no device that
/// holds the old one and no recovery code either.
///
/// This exists because the alternative is a locked door. AbabilX keeps no copy
/// of anyone's private key — that is what end-to-end encryption means — so a
/// person in that position cannot be handed the old identity by anybody, not by
/// support, not by us. Without this path the account can never send a secure
/// message again, which is worse than losing the old ones.
///
/// The cost is real and irreversible: every message already on the account
/// stays sealed to a key that no longer exists anywhere. That is why an emailed
/// code gates it — replacing an identity is exactly what somebody who had
/// stolen an account would want to do — and why the UI states the loss before
/// it asks for anything.
extension MessageVaultReset on MessageVault {
  /// Mints a new identity with a new recovery code, publishes both under
  /// [code], and adopts them here. Returns the code to show.
  ///
  /// The recovery copy travels in the same request as the reset: the emailed
  /// code is spent by then, so a client that stopped in between would leave the
  /// account with an identity stranded on one device — the exact situation this
  /// reset was needed to escape.
  ///
  /// Order matters. The server is asked first, so a rejected or expired code
  /// leaves this device exactly as it was rather than holding a key the account
  /// does not recognise.
  Future<String> startFreshIdentity(String code) async {
    final identity = P256Ecdh.newKeyPair();
    final publicJwk = _publicJwkFromIdentity(identity);
    final recoveryCode = RecoveryKey.generateCode();
    final vault = await RecoveryKey.wrap(
      _privateJwkFromIdentity(identity),
      recoveryCode,
    );
    await _repo.resetE2eeVault(code, publicJwk, vault.toJson());
    // Every cached conversation key was agreed with the retired identity, so it
    // decrypts nothing now. _adopt clears them, forcing a re-agreement under
    // the new key instead of silently failing every message.
    await _adopt(identity, publicJwk);
    return RecoveryKey.format(recoveryCode);
  }
}
