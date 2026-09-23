import 'dart:async';

import 'package:ababilx/core/storage/secure_storage.dart';
import 'package:ababilx/features/notifications/data/device_repository.dart';
import 'package:ababilx/features/notifications/fcm_service.dart';
import 'package:ababilx/features/notifications/local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

class _Messaging implements FirebaseMessaging {
  final refresh = StreamController<String>.broadcast();
  Completer<RemoteMessage?>? initial;
  int permissionRequests = 0;
  @override
  Future<RemoteMessage?> getInitialMessage() async => initial?.future;
  @override
  Future<String?> getToken({String? vapidKey}) async => 'token';
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #requestPermission) {
      permissionRequests++;
      return Future<NotificationSettings>.value(_DeniedSettings());
    }
    return super.noSuchMethod(invocation);
  }
}

class _DeniedSettings implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.denied;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Local implements LocalNotifications {
  @override
  Future<void> init({required void Function(String) onTap}) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements SecureStorage {
  String? token;
  @override
  Future<String?> readFcmToken() async => token;
  @override
  Future<void> writeFcmToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteFcmToken() async {
    token = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Devices implements DeviceRepository {
  final registered = <String>[];
  final operations = <String>[];
  bool offline = false;
  Completer<void>? pending;
  @override
  Future<void> register(String token, {String platform = 'android'}) async {
    registered.add(token);
    if (offline) throw StateError('offline');
    await pending?.future;
    operations.add('register');
  }

  @override
  Future<void> deregister(String token) async {
    operations.add('deregister');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Messaging messaging;
  late _Devices devices;
  late FcmService service;
  void prepare() {
    messaging = _Messaging();
    devices = _Devices();
    service = FcmService(
      devices: devices,
      storage: _Storage(),
      localNotifications: _Local(),
      messaging: messaging,
    );
    addTearDown(() {
      service.dispose();
      unawaited(messaging.refresh.close());
    });
  }

  test(
    'denied permission still registers and recovers without prompting again',
    () async {
      prepare();
      devices.offline = true;
      expect(await service.start(), false);
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered, ['token']);
      devices.offline = false;
      await service.retryPendingRegistration();
      expect(devices.registered, ['token', 'token']);
      expect(messaging.permissionRequests, 1);
      messaging.refresh.add('rotated');
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered.last, 'rotated');
    },
  );

  test(
    'slow registration does not block startup; logout drains before delete',
    () async {
      prepare();
      devices.pending = Completer<void>();
      expect(await service.start(), false);
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered, ['token']);
      final stop = service.stopAndDeregister();
      await Future<void>.delayed(Duration.zero);
      expect(devices.operations, isEmpty);
      expect(await service.start(), false, reason: 'no restart during logout');
      expect(messaging.permissionRequests, 1);
      devices.pending!.complete();
      await Future<void>.delayed(Duration.zero);
      await stop;
      expect(devices.operations, ['register', 'deregister']);
      messaging.refresh.add('late');
      await service.retryPendingRegistration();
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered, ['token']);
    },
  );

  test('logout during startup cannot reattach token listeners', () async {
    prepare();
    messaging.initial = Completer<RemoteMessage?>();
    final start = service.start();
    await service.stopAndDeregister();
    messaging.initial!.complete(null);
    expect(await start, false);
    messaging.refresh.add('late');
    await Future<void>.delayed(Duration.zero);
    expect(devices.registered, isEmpty);
    expect(messaging.permissionRequests, 0);
  });

  test('concurrent startup asks once; next login registers again', () async {
    prepare();
    final first = service.start();
    final second = service.start();
    await Future.wait([first, second]);
    await Future<void>.delayed(Duration.zero);
    expect(messaging.permissionRequests, 1);
    expect(devices.registered, ['token']);
    await service.stopAndDeregister();
    await service.start();
    await Future<void>.delayed(Duration.zero);
    expect(devices.registered, ['token', 'token']);
  });
}
