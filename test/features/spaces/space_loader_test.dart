import 'dart:async';

import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:ababilx/features/spaces/data/space_loader.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _offline = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

class _Harness {
  _Harness({
    this.cached,
    required this.fetch,
    this.timeout = const Duration(seconds: 2),
  });

  String? cached;
  Future<String> Function() fetch;
  Duration timeout;
  final states = <SpaceLoad<String>>[];
  String? saved;

  late final loader = SpaceLoader<String>(
    readCache: () async => cached,
    writeCache: (v) async => saved = v,
    fetch: () => fetch(),
    onState: states.add,
    timeout: timeout,
  );
}

void main() {
  test('no cache, network ok: loading then data, saved', () async {
    final h = _Harness(fetch: () async => 'fresh');
    await h.loader.load();
    expect(h.states.first.loading, isTrue);
    expect(h.states.first.data, isNull);
    expect(h.states.last.data, 'fresh');
    expect(h.states.last.loading, isFalse);
    expect(h.states.last.failure, isNull);
    expect(h.saved, 'fresh');
  });

  test('cache is shown at once, then replaced by the network', () async {
    final h = _Harness(cached: 'old', fetch: () async => 'new');
    await h.loader.load();
    expect(h.states.first.data, 'old');
    expect(h.states.first.loading, isTrue);
    expect(h.states.last.data, 'new');
  });

  test('cache + network down: keep the saved copy, report offline', () async {
    final h = _Harness(cached: 'old', fetch: () async => throw _offline);
    await h.loader.load();
    final last = h.states.last;
    expect(last.data, 'old');
    expect(last.loading, isFalse);
    expect(last.failure, SpaceFailure.offline);
    expect(last.showingSaved, isTrue);
    expect(h.saved, isNull, reason: 'a failure must not overwrite the cache');
  });

  test('no cache + failure: no data, failure set, not loading', () async {
    final h = _Harness(fetch: () async => throw const SpaceUnavailable());
    await h.loader.load();
    expect(h.states.last.data, isNull);
    expect(h.states.last.failure, SpaceFailure.unavailable);
    expect(h.states.last.loading, isFalse);
  });

  test('a hung request ends as a failure, never an endless spinner', () async {
    final never = Completer<String>();
    final h = _Harness(
      cached: 'old',
      fetch: () => never.future,
      timeout: const Duration(milliseconds: 50),
    );
    await h.loader.load();
    expect(h.states.last.loading, isFalse);
    expect(h.states.last.failure, SpaceFailure.offline);
    expect(h.states.last.data, 'old');
  });

  test('retry after a failure clears it', () async {
    var fail = true;
    final h = _Harness(fetch: () async => fail ? throw _offline : 'ok');
    await h.loader.load();
    expect(h.states.last.failure, SpaceFailure.offline);
    fail = false;
    await h.loader.refresh();
    expect(h.states.last.failure, isNull);
    expect(h.states.last.data, 'ok');
  });

  test('a broken cache read is ignored, the network still runs', () async {
    final states = <SpaceLoad<String>>[];
    final loader = SpaceLoader<String>(
      readCache: () async => throw const FormatException('corrupt'),
      writeCache: (_) async {},
      fetch: () async => 'fresh',
      onState: states.add,
    );
    await loader.load();
    expect(states.last.data, 'fresh');
  });

  test('a failing cache write does not turn success into failure', () async {
    final states = <SpaceLoad<String>>[];
    final loader = SpaceLoader<String>(
      readCache: () async => null,
      writeCache: (_) async => throw Exception('disk full'),
      fetch: () async => 'fresh',
      onState: states.add,
    );
    await loader.load();
    expect(states.last.data, 'fresh');
    expect(states.last.failure, isNull);
  });

  test('two refreshes at once share one request', () async {
    var calls = 0;
    final gate = Completer<String>();
    final h = _Harness(
      fetch: () {
        calls++;
        return gate.future;
      },
    );
    final a = h.loader.load();
    final b = h.loader.refresh();
    gate.complete('x');
    await Future.wait([a, b]);
    expect(calls, 1);
  });

  test('nothing is emitted after dispose', () async {
    final gate = Completer<String>();
    final h = _Harness(fetch: () => gate.future);
    final f = h.loader.load();
    h.loader.dispose();
    final count = h.states.length;
    gate.complete('late');
    await f;
    expect(h.states.length, count);
  });
}
