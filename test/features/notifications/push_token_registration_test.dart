import 'dart:async';

import 'package:ababilx/features/notifications/data/push_token_registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('failed registration retries without another app launch', (
    tester,
  ) async {
    var attempts = 0;
    final registration = PushTokenRegistration(
      loadToken: () async => 'token',
      saveToken: (_) async {},
      registerToken: (_) async {
        if (++attempts == 1) throw StateError('offline');
      },
      onFailure: (_) {},
    );
    await registration.start();
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, 2);
    await tester.pump(const Duration(minutes: 10));
    await registration.retryPending();
    expect(attempts, 2, reason: 'success stops both timer and resume retries');
    await registration.stop();
  });

  testWidgets('null token and token lookup errors recover', (tester) async {
    var loads = 0;
    final registered = <String>[];
    final registration = PushTokenRegistration(
      loadToken: () async {
        loads++;
        if (loads == 1) return null;
        if (loads == 2) throw StateError('Play Services unavailable');
        return 'token';
      },
      saveToken: (_) async {},
      registerToken: (token) async => registered.add(token),
      onFailure: (_) {},
    );
    await registration.start();
    await tester.pump(const Duration(seconds: 5));
    expect(loads, 2);
    await tester.pump(const Duration(seconds: 9));
    expect(loads, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(registered, ['token']);
    await registration.stop();
  });

  testWidgets('network recovery retries immediately and coalesces requests', (
    tester,
  ) async {
    final pending = Completer<void>();
    var attempts = 0;
    final registration = PushTokenRegistration(
      loadToken: () async => 'token',
      saveToken: (_) async {},
      registerToken: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        await pending.future;
      },
      onFailure: (_) {},
    );
    await registration.start();
    final retry = registration.retryPending();
    final duplicate = registration.retryPending();
    await tester.pump();
    expect(attempts, 2);
    pending.complete();
    await Future.wait([retry, duplicate]);
    await tester.pump(const Duration(minutes: 10));
    expect(attempts, 2);
    await registration.stop();
  });

  testWidgets(
    'rotation during registration leaves the newest token registered',
    (tester) async {
      final pending = Completer<void>();
      final saved = <String>[];
      final registered = <String>[];
      final registration = PushTokenRegistration(
        loadToken: () async => 'old',
        saveToken: (token) async => saved.add(token),
        registerToken: (token) async {
          registered.add(token);
          if (token == 'old') await pending.future;
        },
        onFailure: (_) {},
      );
      final start = registration.start();
      await tester.pump();
      final rotation = registration.tokenChanged('new');
      expect(registered, ['old']);
      pending.complete();
      await Future.wait([start, rotation]);
      expect(saved, ['old', 'new']);
      expect(registered, ['old', 'new']);
      await registration.stop();
    },
  );

  testWidgets('logout waits for POST before DELETE and cancels all retries', (
    tester,
  ) async {
    final pending = Completer<void>();
    final operations = <String>[];
    final registration = PushTokenRegistration(
      loadToken: () async => 'token',
      saveToken: (_) async {},
      registerToken: (_) async {
        await pending.future;
        operations.add('POST');
      },
      onFailure: (_) {},
    );
    final start = registration.start();
    await tester.pump();
    final stop = registration.stop().then((_) => operations.add('DELETE'));
    await registration.retryPending();
    await registration.tokenChanged('late');
    expect(operations, isEmpty);
    pending.complete();
    await Future.wait([start, stop]);
    await tester.pump(const Duration(minutes: 10));
    expect(operations, ['POST', 'DELETE']);
  });

  testWidgets('logout while token loads prevents storage and API writes', (
    tester,
  ) async {
    final token = Completer<String?>();
    var writes = 0;
    final registration = PushTokenRegistration(
      loadToken: () => token.future,
      saveToken: (_) async => writes++,
      registerToken: (_) async => writes++,
      onFailure: (_) {},
    );
    final start = registration.start();
    final stop = registration.stop();
    token.complete('stale');
    await Future.wait([start, stop]);
    expect(writes, 0);
  });

  testWidgets('logout cancels backoff; next session registers again', (
    tester,
  ) async {
    var attempts = 0;
    final registration = PushTokenRegistration(
      loadToken: () async => 'token',
      saveToken: (_) async {},
      registerToken: (_) async {
        attempts++;
        throw StateError('offline');
      },
      onFailure: (_) {},
    );
    await registration.start();
    await registration.stop();
    await tester.pump(const Duration(minutes: 10));
    expect(attempts, 1);
    await registration.start();
    expect(attempts, 2);
    await registration.stop();
  });

  testWidgets('secure storage failure also retries before registering', (
    tester,
  ) async {
    var saves = 0;
    var registrations = 0;
    final registration = PushTokenRegistration(
      loadToken: () async => 'token',
      saveToken: (_) async {
        if (++saves == 1) throw StateError('storage temporarily unavailable');
      },
      registerToken: (_) async => registrations++,
      onFailure: (_) {},
    );
    await registration.start();
    expect(registrations, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(registrations, 1);
    await registration.stop();
  });
}
