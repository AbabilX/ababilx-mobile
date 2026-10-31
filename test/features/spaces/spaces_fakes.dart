import 'package:ababilx/features/spaces/data/space_cache.dart';
import 'package:ababilx/features/spaces/data/space_message.dart';
import 'package:ababilx/features/spaces/data/space_models.dart';
import 'package:ababilx/features/spaces/providers/spaces_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoryKv implements SpaceKv {
  final map = <String, String>{};
  @override
  Future<String?> get(String key) async => map[key];
  @override
  Future<void> set(String key, String value) async => map[key] = value;
  @override
  Future<void> remove(String key) async => map.remove(key);
}

class FakeBackend implements SpacesBackend {
  Object? listError;
  Object? treeError;
  List<SpaceSummary> spaces = const [];
  final trees = <String, SpaceTree>{};
  int listCalls = 0;

  @override
  Future<List<SpaceSummary>> listSpaces() async {
    listCalls++;
    if (listError case final e?) throw e;
    return spaces;
  }

  Object? writeError;
  Object? messagesError;
  Object? sendError;
  List<SpaceMessage> channelMessages = const [];
  final sent = <String>[];

  @override
  Future<SpaceSummary> createSpace(String name) async {
    if (writeError case final e?) throw e;
    return SpaceSummary(id: 'new', name: name);
  }

  @override
  Future<SpaceSummary> joinInvite(String code) async {
    if (writeError case final e?) throw e;
    return SpaceSummary(id: 'joined-$code', name: 'Joined');
  }

  @override
  Future<List<SpaceMessage>> messages(
    String spaceId,
    String channelId, {
    String? before,
  }) async {
    if (messagesError case final e?) throw e;
    return channelMessages;
  }

  @override
  Future<SpaceMessage> send(
    String spaceId,
    String channelId,
    String body, {
    required String clientId,
  }) async {
    if (sendError case final e?) throw e;
    sent.add(body);
    return SpaceMessage(
      id: 'srv-$clientId',
      body: body,
      clientId: clientId,
      authorName: 'Me',
    );
  }

  @override
  Future<SpaceTree> channels(String spaceId) async {
    if (treeError case final e?) throw e;
    return trees[spaceId] ?? SpaceTree(spaceId: spaceId, name: '');
  }
}

/// Stands in for the signed-in state; changing it is a sign-out/sign-in.
final fakeSession = StateProvider<int>((ref) => 1);

List<Override> spacesOverrides(FakeBackend backend, MemoryKv kv) => [
  spacesBackendProvider.overrideWith((ref) {
    ref.watch(spaceSessionProvider);
    return backend;
  }),
  spaceKvProvider.overrideWithValue(kv),
  spaceSessionProvider.overrideWith((ref) => ref.watch(fakeSession)),
  spaceAccountProvider.overrideWith(
    (ref) async => 'user-${ref.watch(spaceSessionProvider)}',
  ),
];

ProviderContainer spacesContainer(FakeBackend backend, MemoryKv kv) =>
    ProviderContainer(overrides: spacesOverrides(backend, kv));

const nethex = SpaceSummary(id: 's1', name: 'NetHex');
const panda = SpaceSummary(id: 's2', name: 'Panda', unread: true, mentions: 2);

SpaceTree sampleTree(String id) => SpaceTree.fromJson(id, {
  'space': {'name': 'NetHex'},
  'channels': [
    {'id': 'c0', 'name': 'general'},
  ],
  'categories': [
    {
      'id': 'k1',
      'name': 'Admin & Management',
      'channels': [
        {'id': 'c1', 'name': 'admin-chat', 'private': true},
        {'id': 'c2', 'name': 'notify', 'kind': 'announcement', 'unread': true},
      ],
    },
    {
      'id': 'k2',
      'name': 'Devs',
      'channels': [
        {'id': 'c3', 'name': 'backend', 'mentions': 4},
      ],
    },
  ],
});
