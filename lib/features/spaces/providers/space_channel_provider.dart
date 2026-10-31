import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/space_loader.dart';
import '../data/space_message.dart';
import 'spaces_providers.dart';

/// Longest body the composer will send (server enforces its own limit).
const spaceMessageMaxChars = 4000;

/// How many of a channel's newest messages are kept for offline reading.
/// The full Drift + FTS5 cache (1000 / 30 days) is phase 5.
const _savedMessages = 50;

/// Which channel: Space + channel, since the API nests them.
typedef SpaceChannelRef = ({String spaceId, String channelId});

/// One channel's timeline, newest first. Messages being sent or that failed
/// live only here and stay through reloads until they go out.
class SpaceChannelNotifier
    extends FamilyNotifier<SpaceLoad<List<SpaceMessage>>, SpaceChannelRef> {
  late SpaceLoader<List<SpaceMessage>> _loader;
  final _unsent = <SpaceMessage>[];

  Future<String> _key() async =>
      'spaces_channel_v1:${await ref.read(spaceAccountProvider.future)}:'
      '${arg.spaceId}:${arg.channelId}';

  @override
  SpaceLoad<List<SpaceMessage>> build(SpaceChannelRef ch) {
    ref.watch(spaceSessionProvider);
    _unsent.clear();
    _loader = SpaceLoader(
      readCache: _readSaved,
      writeCache: _writeSaved,
      fetch: () =>
          ref.read(spacesBackendProvider).messages(ch.spaceId, ch.channelId),
      onState: (s) => state = _withUnsent(s),
    );
    ref.onDispose(_loader.dispose);
    Future.microtask(_loader.load);
    return const SpaceLoad(loading: true);
  }

  Future<void> refresh() => _loader.refresh();

  SpaceLoad<List<SpaceMessage>> _withUnsent(SpaceLoad<List<SpaceMessage>> s) {
    if (_unsent.isEmpty) return s;
    final server = s.data ?? const <SpaceMessage>[];
    final sentIds = {for (final m in server) m.clientId};
    _unsent.removeWhere((m) => sentIds.contains(m.clientId));
    return SpaceLoad(
      data: [..._unsent, ...server],
      loading: s.loading,
      failure: s.failure,
    );
  }

  /// Sends [text]; false when it was refused locally or failed (it stays on
  /// screen marked failed, with Retry).
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || body.length > spaceMessageMaxChars) return false;
    final cid = _clientId();
    final local = SpaceMessage(
      id: 'local-$cid',
      body: body,
      clientId: cid,
      createdAt: DateTime.now(),
      pending: true,
    );
    _unsent.insert(0, local);
    _publish();
    return _deliver(local);
  }

  /// Sends a failed message again with the same client id (no duplicate).
  Future<bool> retry(String clientId) async {
    final i = _unsent.indexWhere((m) => m.clientId == clientId);
    if (i < 0) return false;
    _unsent[i] = _unsent[i].copyWith(pending: true, failed: false);
    _publish();
    return _deliver(_unsent[i]);
  }

  Future<bool> _deliver(SpaceMessage m) async {
    try {
      final saved = await ref
          .read(spacesBackendProvider)
          .send(arg.spaceId, arg.channelId, m.body, clientId: m.clientId);
      _unsent.removeWhere((u) => u.clientId == m.clientId);
      final server = _loader.state.data ?? const <SpaceMessage>[];
      state = _withUnsent(
        SpaceLoad(data: [saved, ...server], failure: _loader.state.failure),
      );
      return true;
    } catch (_) {
      final i = _unsent.indexWhere((u) => u.clientId == m.clientId);
      if (i >= 0) {
        _unsent[i] = _unsent[i].copyWith(pending: false, failed: true);
      }
      _publish();
      return false;
    }
  }

  void _publish() => state = _withUnsent(
    SpaceLoad(
      data: _loader.state.data ?? const [],
      loading: _loader.state.loading,
      failure: _loader.state.failure,
    ),
  );

  Future<List<SpaceMessage>?> _readSaved() async {
    final raw = await ref.read(spaceKvProvider).get(await _key());
    return raw == null ? null : SpaceMessage.listFromJson(jsonDecode(raw));
  }

  Future<void> _writeSaved(List<SpaceMessage> list) async => ref
      .read(spaceKvProvider)
      .set(
        await _key(),
        jsonEncode({
          'messages': [for (final m in list.take(_savedMessages)) m.toJson()],
        }),
      );
}

final _rand = Random.secure();
String _clientId() => List.generate(
  16,
  (_) => _rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

final spaceChannelProvider =
    NotifierProvider.family<
      SpaceChannelNotifier,
      SpaceLoad<List<SpaceMessage>>,
      SpaceChannelRef
    >(SpaceChannelNotifier.new);
