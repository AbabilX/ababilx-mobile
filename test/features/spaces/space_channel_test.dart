import 'package:ababilx/features/spaces/data/space_failure.dart';
import 'package:ababilx/features/spaces/data/space_message.dart';
import 'package:ababilx/features/spaces/providers/space_channel_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spaces_fakes.dart';

final offline = DioException(
  requestOptions: RequestOptions(),
  type: DioExceptionType.connectionError,
);
const _c1 = (spaceId: 's1', channelId: 'c1');

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('loads messages and keeps a saved copy for offline', () async {
    final kv = MemoryKv();
    final b = FakeBackend()
      ..channelMessages = [const SpaceMessage(id: 'm1', body: 'hello')];
    final c = spacesContainer(b, kv);
    c.read(spaceChannelProvider(_c1));
    await settle();
    expect(c.read(spaceChannelProvider(_c1)).data!.single.body, 'hello');
    c.dispose();

    final c2 = spacesContainer(FakeBackend()..messagesError = offline, kv);
    c2.read(spaceChannelProvider(_c1));
    await settle();
    final s = c2.read(spaceChannelProvider(_c1));
    expect(s.data!.single.body, 'hello');
    expect(s.failure, SpaceFailure.offline);
    expect(
      kv.map.keys.where((k) => k.startsWith('spaces_channel_v1:')).single,
      'spaces_channel_v1:user-1:s1:c1',
    );
  });

  test('send shows at once as pending, then the server copy', () async {
    final b = FakeBackend();
    final c = spacesContainer(b, MemoryKv());
    c.read(spaceChannelProvider(_c1));
    await settle();
    final n = c.read(spaceChannelProvider(_c1).notifier);
    final f = n.send('  yo  ');
    final pending = c.read(spaceChannelProvider(_c1)).data!.first;
    expect(pending.pending, isTrue);
    expect(pending.body, 'yo');
    expect(await f, isTrue);
    final done = c.read(spaceChannelProvider(_c1)).data!.first;
    expect(done.pending, isFalse);
    expect(done.id, startsWith('srv-'));
    expect(c.read(spaceChannelProvider(_c1)).data!.length, 1);
  });

  test('a failed send stays, marked failed; retry sends it once', () async {
    final b = FakeBackend()..sendError = offline;
    final c = spacesContainer(b, MemoryKv());
    c.read(spaceChannelProvider(_c1));
    await settle();
    final n = c.read(spaceChannelProvider(_c1).notifier);
    expect(await n.send('keep me'), isFalse);
    final failed = c.read(spaceChannelProvider(_c1)).data!.first;
    expect(failed.failed, isTrue);
    expect(failed.body, 'keep me');

    b.sendError = null;
    expect(await n.retry(failed.clientId), isTrue);
    final list = c.read(spaceChannelProvider(_c1)).data!;
    expect(list.length, 1);
    expect(list.first.failed, isFalse);
    expect(b.sent, ['keep me']);
  });

  test('a reload keeps unsent messages above the server page', () async {
    final b = FakeBackend()..sendError = offline;
    final c = spacesContainer(b, MemoryKv());
    c.read(spaceChannelProvider(_c1));
    await settle();
    final n = c.read(spaceChannelProvider(_c1).notifier);
    await n.send('draft');
    b.channelMessages = [const SpaceMessage(id: 'm1', body: 'server')];
    await n.refresh();
    final bodies = c.read(spaceChannelProvider(_c1)).data!.map((m) => m.body);
    expect(bodies, ['draft', 'server']);
  });

  test('empty and oversized bodies are not sent', () async {
    final b = FakeBackend();
    final c = spacesContainer(b, MemoryKv());
    c.read(spaceChannelProvider(_c1));
    await settle();
    final n = c.read(spaceChannelProvider(_c1).notifier);
    expect(await n.send('   '), isFalse);
    expect(await n.send('x' * (spaceMessageMaxChars + 1)), isFalse);
    expect(b.sent, isEmpty);
  });
}
