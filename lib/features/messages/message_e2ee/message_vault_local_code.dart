part of 'message_vault.dart';

/// Recovery codes stay only in this phone's OS secure storage.
extension MessageVaultLocalCode on MessageVault {
  String _recoveryStorageId(Map<String, dynamic> public) =>
      '${public['x']}_${public['y']}';

  Future<void> _storeRecoveryCode(Map<String, dynamic> public, String code) =>
      _storage.writeRecoveryCode(_recoveryStorageId(public), code);

  Future<bool> hasStoredRecoveryCode() async {
    final public = _publicJwk;
    if (public != null) await _reconcileRecoveryCode(public);
    if (public == null) return false;
    final code = await _storage.readRecoveryCode(_recoveryStorageId(public));
    return code != null && await _codeMatchesCurrentVault(code, public);
  }

  Future<String> readVerifiedRecoveryCode(Map<String, dynamic> response) async {
    final public = response['public_key'];
    if (response['verified'] != true ||
        _identity == null ||
        public is! Map ||
        public['x'] != _publicJwk?['x'] ||
        public['y'] != _publicJwk?['y']) {
      throw StateError('Unlock and verify the current message identity first');
    }
    await _reconcileRecoveryCode(_publicJwk!);
    final code = await _storage.readRecoveryCode(
      _recoveryStorageId(_publicJwk!),
    );
    if (code == null || !await _codeMatchesCurrentVault(code, _publicJwk!)) {
      throw StateError('No current recovery code saved on this phone');
    }
    return code;
  }

  Future<bool> _codeMatchesCurrentVault(
    String input,
    Map<String, dynamic> public,
  ) async {
    final status = await _repo.getE2eeVault();
    final remote = status['vault'];
    if (remote is! Map || remote['recovery'] is! Map) return false;
    final code = RecoveryKey.parse(input);
    if (code == null) return false;
    try {
      final private = await RecoveryKey.unwrap(
        RecoveryVault.fromJson(
          Map<String, dynamic>.from(remote['recovery'] as Map),
        ),
        code,
      );
      return private['x'] == public['x'] && private['y'] == public['y'];
    } catch (_) {
      return false;
    }
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
