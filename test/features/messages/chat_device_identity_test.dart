import 'package:ababilx/features/messages/data/chat_device_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'messaging device identity round-trips without losing key bytes',
    () async {
      final created = await LocalChatDeviceIdentity.generate(
        deviceId: 'test-device-123',
      );
      final restored = LocalChatDeviceIdentity.fromJson(created.toJson());

      expect(restored.deviceId, created.deviceId);
      expect(restored.privateKey.d, created.privateKey.d);
      expect(restored.privateKey.x, created.privateKey.x);
      expect(restored.privateKey.y, created.privateKey.y);
      expect(restored.publicKey, created.publicKey);
    },
  );

  test(
    'server key version update preserves the local private identity',
    () async {
      final created = await LocalChatDeviceIdentity.generate(
        deviceId: 'test-device-456',
      );
      final updated = created.withVersion(4);

      expect(updated.keyVersion, 4);
      expect(updated.privateKey.d, created.privateKey.d);
      expect(updated.rotatedAt, created.rotatedAt);
    },
  );
}
