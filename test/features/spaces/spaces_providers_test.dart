import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:ababilx/features/spaces/data/space_models.dart';
import 'package:ababilx/features/spaces/providers/spaces_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spaces_fakes.dart';

final offline = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('list loads from the network and is saved for next time', () async {
    final b = FakeBackend()..spaces = [nethex, panda];
    final kv = MemoryKv();
    final c = spacesContainer(b, kv);
    c.read(spacesListProvider);
    await settle();
    expect(c.read(spacesListProvider).data!.map((s) => s.id), ['s1', 's2']);
    c.dispose();

    // Next launch, offline: the saved copy is drawn, with the failure.
    final b2 = FakeBackend()..listError = offline;
    final c2 = spacesContainer(b2, kv);
    c2.read(spacesListProvider);
    await settle();
    final s = c2.read(spacesListProvider);
    expect(s.data!.length, 2);
    expect(s.failure, SpaceFailure.offline);
    expect(s.loading, isFalse);
  });

  test('cache is per account', () async {
    final kv = MemoryKv();
    final c = spacesContainer(FakeBackend()..spaces = [nethex], kv);
    c.read(spacesListProvider);
    await settle();
    expect(kv.map.keys.any((k) => k.contains('user-1')), isTrue);
    c.dispose();
  });

  test('selection: saved choice, else first; survives restart', () async {
    final kv = MemoryKv();
    final b = FakeBackend()..spaces = [nethex, panda];
    final c = spacesContainer(b, kv);
    c.read(spacesListProvider);
    await settle();
    expect(c.read(selectedSpaceIdProvider), 's1');
    await c.read(selectedSpaceNotifierProvider.notifier).select('s2');
    expect(c.read(selectedSpaceIdProvider), 's2');
    c.dispose();

    final c2 = spacesContainer(b, kv);
    c2.read(spacesListProvider);
    c2.read(selectedSpaceNotifierProvider);
    await settle();
    expect(c2.read(selectedSpaceIdProvider), 's2');
  });

  test(
    'a saved selection for a space you left falls back to the first',
    () async {
      final kv = MemoryKv();
      final c = spacesContainer(FakeBackend()..spaces = [nethex], kv);
      c.read(spacesListProvider);
      await c.read(selectedSpaceNotifierProvider.notifier).select('gone');
      await settle();
      expect(c.read(selectedSpaceIdProvider), 's1');
    },
  );

  test('no spaces: selection is null', () async {
    final c = spacesContainer(FakeBackend(), MemoryKv());
    c.read(spacesListProvider);
    await settle();
    expect(c.read(selectedSpaceIdProvider), isNull);
  });

  test('tree loads per space and keeps its saved copy on failure', () async {
    final kv = MemoryKv();
    final b = FakeBackend()..trees['s1'] = sampleTree('s1');
    final c = spacesContainer(b, kv);
    c.read(spaceTreeProvider('s1'));
    await settle();
    expect(c.read(spaceTreeProvider('s1')).data!.categories.length, 2);
    c.dispose();

    final c2 = spacesContainer(
      FakeBackend()..treeError = const SpaceUnavailable(),
      kv,
    );
    c2.read(spaceTreeProvider('s1'));
    await settle();
    final s = c2.read(spaceTreeProvider('s1'));
    expect(s.data!.channel('c3')!.mentions, 4);
    expect(s.failure, SpaceFailure.unavailable);
  });

  test('collapsed categories toggle and persist', () async {
    final kv = MemoryKv();
    final c = spacesContainer(FakeBackend(), kv);
    c.read(collapsedCategoriesProvider);
    await settle();
    await c.read(collapsedCategoriesProvider.notifier).toggle('k1');
    expect(c.read(collapsedCategoriesProvider), {'k1'});
    c.dispose();
    final c2 = spacesContainer(FakeBackend(), kv);
    c2.read(collapsedCategoriesProvider);
    await settle();
    expect(c2.read(collapsedCategoriesProvider), {'k1'});
    await c2.read(collapsedCategoriesProvider.notifier).toggle('k1');
    expect(c2.read(collapsedCategoriesProvider), isEmpty);
  });

  test('corrupt cache is ignored', () async {
    final kv = MemoryKv()..map['spaces_list_v1:user-1'] = '{not json';
    final c = spacesContainer(FakeBackend()..spaces = [nethex], kv);
    c.read(spacesListProvider);
    await settle();
    expect(c.read(spacesListProvider).data!.single.id, 's1');
  });

  test('account switch drops the old account\'s state and refetches', () async {
    final kv = MemoryKv();
    final b = FakeBackend()..spaces = [nethex];
    final c = spacesContainer(b, kv);
    c.listen(spacesListProvider, (_, _) {});
    await settle();
    await c.read(selectedSpaceNotifierProvider.notifier).select('s1');
    expect(c.read(spacesListProvider).data!.single.id, 's1');

    // Sign out, sign in as someone else.
    b.spaces = [panda];
    c.read(fakeSession.notifier).state = 2;
    await settle();
    expect(c.read(spacesListProvider).data!.single.id, 's2');
    expect(b.listCalls, 2);
    expect(kv.map.keys.any((k) => k.contains('user-2')), isTrue);
  });

  test('unused import guard', () => expect(SpaceChannelKind.text.name, 'text'));
}
