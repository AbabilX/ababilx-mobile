import 'dart:async';

import 'package:ababilx/features/messages/data/request_single_flight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coalesces concurrent work for the same request key', () async {
    final gate = Completer<int>();
    final singleFlight = RequestSingleFlight<int>();
    var calls = 0;

    Future<int> request() => singleFlight.run('same-page', () {
      calls++;
      return gate.future;
    });

    final first = request();
    final second = request();
    expect(calls, 1);

    gate.complete(42);
    expect(await Future.wait([first, second]), [42, 42]);
  });

  test('allows a new request after the previous one completes', () async {
    final singleFlight = RequestSingleFlight<int>();
    var calls = 0;

    await singleFlight.run('page', () async => ++calls);
    await singleFlight.run('page', () async => ++calls);

    expect(calls, 2);
  });
}
