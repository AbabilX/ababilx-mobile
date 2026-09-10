part of 'message_vault.dart';

extension MessageVaultSession on MessageVault {
  void beginNewChat() {
    lock();
    _newChatPending = true;
  }

  /// Persist the exact candidate before any network write. A process death or
  /// lost response retries this identity, never generates an orphaned key.
  Future<void> startSession({
    required String userId,
    required ChatRecoveryApi api,
    Map<String, dynamic>? expectedPublicKey,
    bool clearHistory = false,
  }) => _sessionOperation ??= _startSession(
    userId,
    api,
    expectedPublicKey,
    clearHistory,
  ).whenComplete(() => _sessionOperation = null);

  Future<void> _startSession(
    String userId,
    ChatRecoveryApi api,
    Map<String, dynamic>? expectedPublicKey,
    bool clearHistory,
  ) async {
    final epoch = _recoveryEpoch;
    var saved = await _storage.readPendingRecovery(userId);
    if (saved == null) {
      final identity = P256Ecdh.newKeyPair();
      final code = RecoveryKey.generateCode();
      final wrapping = await RecoveryKey.wrap(
        _privateJwkFromIdentity(identity),
        code,
      );
      saved = jsonEncode({
        'private_key': _privateJwkFromIdentity(identity),
        'recovery_code': RecoveryKey.format(code),
        'body': {
          if (clearHistory) 'clear_history': true,
          'expected_public_key': ?expectedPublicKey,
          'public_key': _publicJwkFromIdentity(identity),
          ...wrapping.toJson(),
        },
      });
      _checkRecoveryEpoch(epoch);
      await _storage.writePendingRecovery(userId, saved);
    }
    _checkRecoveryEpoch(epoch);
    await _commitSession(userId, saved, api);
  }

  Future<bool> resumePendingSession(String userId, ChatRecoveryApi api) async {
    final saved = await _storage.readPendingRecovery(userId);
    if (saved == null) return false;
    await (_sessionOperation ??= _commitSession(
      userId,
      saved,
      api,
    ).whenComplete(() => _sessionOperation = null));
    return true;
  }

  Future<void> _commitSession(
    String userId,
    String saved,
    ChatRecoveryApi api,
  ) async {
    final epoch = _recoveryEpoch;
    final pending = Map<String, dynamic>.from(jsonDecode(saved) as Map);
    final body = Map<String, dynamic>.from(pending['body'] as Map);
    final public = Map<String, dynamic>.from(body['public_key'] as Map);
    if (body['clear_history'] == true) _newChatPending = true;
    try {
      await api.startSession(body);
    } catch (_) {
      final status = await _repo.getE2eeVault();
      final remote = status['vault'];
      final current = remote is Map ? remote['public_key'] : null;
      if (current is! Map ||
          current['x'] != public['x'] ||
          current['y'] != public['y']) {
        final expected = body['expected_public_key'];
        // A competing device won. Discard this unused candidate so the next
        // check can offer recovery for the winning identity.
        if (current is Map &&
            (expected is! Map ||
                current['x'] != expected['x'] ||
                current['y'] != expected['y'])) {
          await _storage.deletePendingRecovery(userId);
        }
        rethrow;
      }
    }
    _checkRecoveryEpoch(epoch);
    if (body['clear_history'] == true) {
      await onHistoryReset?.call(userId);
      _checkRecoveryEpoch(epoch);
    }
    await _adopt(
      _identityFromJwk(
        Map<String, dynamic>.from(pending['private_key'] as Map),
      ),
      public,
    );
    await _storeRecoveryCode(public, pending['recovery_code'] as String);
    _backfilled.clear();
    await _storage.deletePendingRecovery(userId);
    _newChatPending = false;
  }

  void _checkRecoveryEpoch(int epoch) {
    if (epoch != _recoveryEpoch) throw StateError('Recovery session cancelled');
  }

  Future<void> cancelRecoverySession() async {
    _recoveryEpoch++;
    try {
      await _sessionOperation;
    } catch (_) {}
    lock();
    _newChatPending = false;
  }

  Future<bool> adoptCurrentIdentity(Map<String, dynamic> public) =>
      _adoptStoredIdentity(public);
}
