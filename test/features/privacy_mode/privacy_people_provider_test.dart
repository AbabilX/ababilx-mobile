import 'dart:async';

import 'package:ababilx/core/constants/api_constants.dart';
import 'package:ababilx/core/network/api_client.dart';
import 'package:ababilx/features/auth/providers/auth_provider.dart';
import 'package:ababilx/features/privacy-mode/people/privacy_people_provider.dart';
import 'package:ababilx/features/privacy-mode/people/privacy_person.dart';
import 'package:ababilx/features/privacy-mode/people/privacy_toward_provider.dart';
import 'package:ababilx/features/privacy-mode/privacy_mode_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _b = 'bbbbbbbb-0000-0000-0000-000000000000';
const _c = 'cccccccc-0000-0000-0000-000000000000';

/// The server: the switch, and per-person modes. A test holds a GET or PUT
/// open to decide when its reply lands, or makes either fail.
class _FakeApi implements ApiClient {
  bool switchOn = false;
  Map<String, String> people = {};
  Completer<void>? holdPeopleGet;
  bool failGet = false;
  bool failPut = false;

  Response<T> _ok<T>(String path, Object data) => Response<T>(
    requestOptions: RequestOptions(path: path),
    data: {'success': true, 'data': data} as T,
  );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (failGet) throw DioException(requestOptions: RequestOptions(path: path));
    if (path == ApiConstants.mePrivacyMode) {
      return _ok(path, {'enabled': switchOn});
    }
    final snapshot = {...people};
    await holdPeopleGet?.future;
    return _ok(path, {
      'people': [
        for (final e in snapshot.entries)
          {'user_id': e.key, 'mode': e.value, 'name': 'N${e.key[0]}'},
      ],
    });
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    if (failPut) throw DioException(requestOptions: RequestOptions(path: path));
    final mode = (data as Map)['mode'] as String;
    final id = path.split('/').last;
    mode == 'default' ? people.remove(id) : people[id] = mode;
    return _ok(path, {'user_id': id, 'mode': mode});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_FakeApi api) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

PrivacyPerson _p(String id, PrivacyPersonMode mode) =>
    PrivacyPerson(userId: id, mode: mode);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a choice beats the switch in both directions', () {
    for (final on in [true, false]) {
      expect(PrivacyPersonMode.follow.appliesWith(switchOn: on), on);
      expect(PrivacyPersonMode.always.appliesWith(switchOn: on), isTrue);
      expect(PrivacyPersonMode.never.appliesWith(switchOn: on), isFalse);
    }
  });

  test('rows the server would never hold are dropped', () {
    expect(PrivacyPerson.fromJson({'user_id': _b, 'mode': 'default'}), isNull);
    expect(PrivacyPerson.fromJson({'user_id': _b, 'mode': 'maybe'}), isNull);
    expect(PrivacyPerson.fromJson({'mode': 'always'}), isNull);
  });

  test('loads the list, and the effective rule follows it', () async {
    final api = _FakeApi()
      ..switchOn = true
      ..people = {_c: 'never'};
    final c = _container(api);
    final people = await c.read(privacyPeopleProvider.notifier).resolve();
    expect(people[_c]?.mode, PrivacyPersonMode.never);
    expect(people[_c]?.name, 'Nc');
    await c.read(privacyModeProvider.notifier).resolve();
    expect(c.read(privacyTowardProvider(_b)), isTrue); // follows the switch
    expect(c.read(privacyTowardProvider(_c)), isFalse); // exempt
  });

  test('a refused save puts the previous choice back', () async {
    final api = _FakeApi();
    final c = _container(api);
    final notifier = c.read(privacyPeopleProvider.notifier);
    await notifier.resolve();

    api.failPut = true;
    expect(await notifier.set(_p(_b, PrivacyPersonMode.always)), isFalse);
    expect(notifier.modeFor(_b), PrivacyPersonMode.follow);
  });

  test('a slow fetch cannot undo a choice made meanwhile', () async {
    final api = _FakeApi()..holdPeopleGet = Completer<void>();
    final c = _container(api);
    final notifier = c.read(privacyPeopleProvider.notifier);

    await notifier.set(_p(_b, PrivacyPersonMode.always));
    api.holdPeopleGet!.complete(); // the stale GET (said "nobody") lands now
    final people = await notifier.resolve();
    expect(people[_b]?.mode, PrivacyPersonMode.always);
  });

  test('another device clearing a choice removes it here', () async {
    final api = _FakeApi()..people = {_b: 'always'};
    final c = _container(api);
    final notifier = c.read(privacyPeopleProvider.notifier);
    await notifier.resolve();

    notifier.applyRemote(_b, PrivacyPersonMode.follow);
    expect(c.read(privacyPeopleProvider), isEmpty);
  });

  test('an offline cold start still knows the choice', () async {
    final online = _FakeApi();
    final first = _container(online);
    await first.read(privacyPeopleProvider.notifier).resolve();
    await first
        .read(privacyPeopleProvider.notifier)
        .set(_p(_b, PrivacyPersonMode.always));
    await pumpEventQueue();
    first.dispose();

    final offline = _FakeApi()..failGet = true;
    final second = _container(offline);
    final people = await second.read(privacyPeopleProvider.notifier).resolve();
    expect(people[_b]?.mode, PrivacyPersonMode.always);
    expect(second.read(privacyTowardProvider(_b)), isTrue);
  });
}
