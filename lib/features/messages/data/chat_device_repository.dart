import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import 'chat_device_identity.dart';

class ChatDeviceRepository {
  ChatDeviceRepository(this._client)
    : _storage = const SecureStorage(FlutterSecureStorage());

  final ApiClient _client;
  final SecureStorage _storage;
  Future<LocalChatDeviceIdentity>? _syncing;

  static const _rotateAfter = Duration(days: 90);

  Future<LocalChatDeviceIdentity> ensureRegistered() async {
    final syncing = _syncing ??= _sync();
    try {
      return await syncing;
    } catch (_) {
      if (identical(_syncing, syncing)) _syncing = null;
      rethrow;
    }
  }

  Future<LocalChatDeviceIdentity> _sync() async {
    var local = await _loadOrCreate();
    final server = await _registerOrRecover(local);
    local = local.withVersion((server['key_version'] as num).toInt());
    if (DateTime.now().toUtc().difference(local.rotatedAt) >= _rotateAfter) {
      final candidate = await LocalChatDeviceIdentity.generate(
        deviceId: local.deviceId,
      );
      final rotated = await _rotate(
        candidate,
        (server['key_version'] as num).toInt(),
      );
      local = LocalChatDeviceIdentity(
        deviceId: candidate.deviceId,
        privateKey: candidate.privateKey,
        publicKey: candidate.publicKey,
        keyVersion: (rotated['key_version'] as num).toInt(),
        createdAt: local.createdAt,
        rotatedAt: candidate.rotatedAt,
      );
    }
    await _save(local);
    return local;
  }

  Future<Map<String, dynamic>> _registerOrRecover(
    LocalChatDeviceIdentity local,
  ) async {
    try {
      final response = await _client.post(
        ApiConstants.messagingDevices,
        data: {
          'device_id': local.deviceId,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'public_key': local.publicKey,
        },
      );
      return unwrapApiData<Map<String, dynamic>>(response);
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is! Map || data['error'] != 'device_key_conflict') rethrow;
      final current = (data['current_key_version'] as num?)?.toInt();
      if (current == null || current < 1) rethrow;
      return _rotate(local, current);
    }
  }

  Future<Map<String, dynamic>> _rotate(
    LocalChatDeviceIdentity local,
    int expectedVersion,
  ) async {
    final response = await _client.put(
      ApiConstants.messagingDeviceKey(local.deviceId),
      data: {
        'expected_key_version': expectedVersion,
        'public_key': local.publicKey,
      },
    );
    return unwrapApiData<Map<String, dynamic>>(response);
  }

  Future<void> acknowledge(String status, List<String> messageIds) async {
    final ids = messageIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return;
    final device = await ensureRegistered();
    for (var offset = 0; offset < ids.length; offset += 200) {
      final end = offset + 200 < ids.length ? offset + 200 : ids.length;
      await _client.post(
        ApiConstants.messagingReceipts,
        data: {
          'device_id': device.deviceId,
          'status': status,
          'message_ids': ids.sublist(offset, end),
        },
      );
    }
  }

  Future<LocalChatDeviceIdentity> _loadOrCreate() async {
    final saved = await _storage.readMessagingDeviceIdentity();
    if (saved != null) {
      try {
        return LocalChatDeviceIdentity.fromJson(
          Map<String, dynamic>.from(jsonDecode(saved) as Map),
        );
      } catch (_) {}
    }
    final created = await LocalChatDeviceIdentity.generate();
    await _save(created);
    return created;
  }

  Future<void> _save(LocalChatDeviceIdentity identity) =>
      _storage.writeMessagingDeviceIdentity(jsonEncode(identity.toJson()));
}
