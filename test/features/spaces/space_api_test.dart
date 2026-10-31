import 'package:ababilx/features/spaces/data/space_api.dart';
import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late SpaceApi api;

  setUp(() {
    adapter = FakeAdapter((_) => (200, ok({'spaces': []})));
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    api = SpaceApi(dio: dio);
  });

  test('lists spaces from the main API', () async {
    adapter.handler = (_) => (
      200,
      ok({
        'spaces': [
          {'id': 's1', 'name': 'A'},
        ],
      }),
    );
    final list = await api.listSpaces();
    expect(list.single.id, 's1');
    expect(adapter.requests.single.path, '/api/spaces');
  });

  test('channels: space id is path-escaped', () async {
    adapter.handler = (_) => (
      200,
      ok({
        'space': {'name': 'X'},
        'categories': [],
      }),
    );
    final tree = await api.channels('a/../b');
    expect(tree.name, 'X');
    expect(adapter.requests.single.uri.path, '/api/spaces/a%2F..%2Fb/channels');
  });

  test('a success:false envelope is a failure, not empty data', () async {
    adapter.handler = (_) => (200, {'success': false, 'error': 'x'});
    await expectLater(api.listSpaces(), throwsA(anything));
  });

  test('404 (routes not deployed yet) classifies as unavailable', () async {
    adapter.handler = (_) => (404, {'success': false, 'error': 'not_found'});
    try {
      await api.listSpaces();
      fail('no throw');
    } catch (e) {
      expect(classifySpaceError(e), SpaceFailure.unavailable);
    }
  });

  test('a 401 is not retried here (ApiClient refreshes)', () async {
    adapter.handler = (_) => (401, {'success': false});
    await expectLater(api.listSpaces(), throwsA(isA<DioException>()));
    expect(adapter.requests.length, 1);
  });
}
