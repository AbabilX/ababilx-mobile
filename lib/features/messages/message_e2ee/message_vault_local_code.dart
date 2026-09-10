part of 'message_vault.dart';

/// Recovery codes stay only in this phone's OS secure storage.
extension MessageVaultLocalCode on MessageVault {
  String _recoveryStorageId(Map<String, dynamic> public) =>
      '${public['x']}_${public['y']}';

  Future<void> _storeRecoveryCode(Map<String, dynamic> public, String code) =>
      _storage.writeRecoveryCode(_recoveryStorageId(public), code);

  /// Reading an already saved code is entirely local and works offline.
  Future<String?> readStoredRecoveryCode() async {
    final public = _publicJwk;
    if (_identity == null || public == null) {
      throw StateError('Unlock the current message identity first');
    }
    return _storage.readRecoveryCode(_recoveryStorageId(public));
  }

  Future<void> _publishRecoveryCode(
    Map<String, dynamic> public,
    List<int> code,
    RecoveryVault wrapping,
  ) async {
    final id = 'rotation_${_recoveryStorageId(public)}';
    final formatted = RecoveryKey.format(code);
    await _storage.writePendingRecovery(
      id,
      jsonEncode({'code': formatted, 'vault': wrapping.toJson()}),
    );
    try {
      await _repo.putE2eeRecoveryVault(public, wrapping.toJson());
    } catch (_) {
      if (!await _reconcileRecoveryCode(public)) rethrow;
      return;
    }
    await _storeRecoveryCode(public, formatted);
    await _storage.deletePendingRecovery(id);
  }

  Future<bool> _reconcileRecoveryCode(Map<String, dynamic> public) async {
    final id = 'rotation_${_recoveryStorageId(public)}';
    final saved = await _storage.readPendingRecovery(id);
    if (saved == null) return false;
    final pending = Map<String, dynamic>.from(jsonDecode(saved) as Map);
    final status = await _repo.getE2eeVault();
    final remote = status['vault'];
    final recovery = remote is Map ? remote['recovery'] : null;
    final candidate = pending['vault'] as Map;
    if (recovery is Map &&
        recovery['salt'] == candidate['salt'] &&
        (recovery['wrapped_key'] as Map?)?['ciphertext'] ==
            (candidate['wrapped_key'] as Map)['ciphertext']) {
      await _storeRecoveryCode(public, pending['code'] as String);
      await _storage.deletePendingRecovery(id);
      return true;
    }
    return false;
  }
}
