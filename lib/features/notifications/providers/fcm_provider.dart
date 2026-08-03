import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/device_repository.dart';
import '../fcm_service.dart';
import '../local_notifications.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(apiClientProvider)),
);

final localNotificationsProvider = Provider<LocalNotifications>(
  (_) => LocalNotifications(),
);

final fcmServiceProvider = Provider<FcmService>(
  (ref) => FcmService(
    devices: ref.watch(deviceRepositoryProvider),
    storage: ref.watch(secureStorageProvider),
    localNotifications: ref.watch(localNotificationsProvider),
  ),
);

/// Tracks whether Android notification permission is granted.
class NotificationPermissionNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void setGranted(bool granted) => state = granted;
}

final notificationPermissionProvider =
    NotifierProvider<NotificationPermissionNotifier, bool?>(
      NotificationPermissionNotifier.new,
    );
