import 'dart:convert';

import '../../notifications/data/device_identity.dart';
import '../message_e2ee/p256_ecdh.dart';

class LocalChatDeviceIdentity {
  const LocalChatDeviceIdentity({
    required this.deviceId,
    required this.privateKey,
    required this.publicKey,
    required this.keyVersion,
    required this.createdAt,
    required this.rotatedAt,
  });

  final String deviceId;
  final P256KeyPair privateKey;
  final Map<String, dynamic> publicKey;
  final int keyVersion;
  final DateTime createdAt;
  final DateTime rotatedAt;

  static Future<LocalChatDeviceIdentity> generate({String? deviceId}) async {
    final key = P256Ecdh.newKeyPair();
    final now = DateTime.now().toUtc();
    return LocalChatDeviceIdentity(
      deviceId: deviceId ?? await DeviceIdentity.get(),
      privateKey: key,
      publicKey: {
        'kty': 'EC',
        'crv': 'P-256',
        'x': _encode(key.x),
        'y': _encode(key.y),
        'ext': true,
        'key_ops': <String>[],
      },
      keyVersion: 0,
      createdAt: now,
      rotatedAt: now,
    );
  }

  factory LocalChatDeviceIdentity.fromJson(Map<String, dynamic> json) {
    final privateKey = Map<String, dynamic>.from(json['private_key'] as Map);
    final publicKey = Map<String, dynamic>.from(json['public_key'] as Map);
    return LocalChatDeviceIdentity(
      deviceId: json['device_id'] as String,
      privateKey: P256KeyPair(
        d: P256Ecdh.encodeCoordinate(
          P256Ecdh.decodeCoordinate(_decode(privateKey['d'] as String)),
        ),
        x: P256Ecdh.encodeCoordinate(
          P256Ecdh.decodeCoordinate(_decode(publicKey['x'] as String)),
        ),
        y: P256Ecdh.encodeCoordinate(
          P256Ecdh.decodeCoordinate(_decode(publicKey['y'] as String)),
        ),
      ),
      publicKey: publicKey,
      keyVersion: (json['key_version'] as num? ?? 0).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      rotatedAt: DateTime.parse(json['rotated_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'private_key': {'d': _encode(privateKey.d)},
    'public_key': publicKey,
    'key_version': keyVersion,
    'created_at': createdAt.toIso8601String(),
    'rotated_at': rotatedAt.toIso8601String(),
  };

  LocalChatDeviceIdentity withVersion(int version) => LocalChatDeviceIdentity(
    deviceId: deviceId,
    privateKey: privateKey,
    publicKey: publicKey,
    keyVersion: version,
    createdAt: createdAt,
    rotatedAt: rotatedAt,
  );

  static String _encode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
  static List<int> _decode(String value) =>
      base64Url.decode(base64Url.normalize(value));
}
