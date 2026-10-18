import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/ws_client.dart';
import '../../../attachments/providers/attachment_providers.dart';
import '../../data/local/chat_message_store.dart';
import '../../message_e2ee/message_vault.dart';
import '../../providers/chat_provider.dart';
import '../history_transfer_local_conversations.dart';
import '../history_window.dart';
import 'live_answers.dart';
import 'live_api.dart';
import 'live_channel.dart';
import 'live_links.dart';
import 'live_signal_seal.dart';
import 'live_state.dart';

export 'live_state.dart';

/// The phone's side of live history links (server 0175,
/// `ababilx-server/docs/history-live-protocol.md`).
///
/// A link is made once, when the phone approves a one-scan sign-in; from
/// then on the computer asks for a connection (`history.wake`) whenever it
/// needs something only this phone has — the newest messages of every chat
/// right after linking, older pages as someone scrolls, a file on tap — and
/// this answers it. The server relays sealed signals and sees nothing else.
class HistoryLiveNotifier extends Notifier<HistoryLiveState> {
  final _links = LiveLinks();
  LiveChannel? _channel;
  LiveLink? _link;
  bool _opening = false;
  DateTime? _offeredAt;

  /// An offer's time to connect before a wake may replace it (TURN is slow).
  static const _negotiateFor = Duration(seconds: 15);
  Future<void> _signalsIn = Future.value();
  Future<void> _signalsOut = Future.value();

  String get _userId => ref.read(chatProvider).currentUserId;

  @override
  HistoryLiveState build() {
    final sub = ref.read(wsClientProvider).events.listen(_onEvent);
    ref.onDispose(() {
      unawaited(sub.cancel());
      unawaited(_channel?.close());
    });
    return const HistoryLiveState();
  }

  /// Right after approving a one-scan sign-in with `live: true`.
  Future<void> adopt({
    required String linkId,
    required List<int> key,
    required String device,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      debugPrint('[HistoryLive] adopt skipped: no user id');
      return;
    }
    await _links.save(userId, LiveLink(id: linkId, key: key, device: device));
  }

  void _onEvent(Map<String, dynamic> ev) {
    final type = ev['type'];
    final id = ev['id'] as String? ?? '';
    if (id.isEmpty) return;
    if (type == 'history.wake') {
      debugPrint('[HistoryLive] wake link=$id');
      unawaited(_open(id));
    } else if (type == 'history.signal' && ev['from_role'] == 'destination') {
      final raw = ev['history_signal'];
      if (raw is Map) _onSignal(id, Map<String, dynamic>.from(raw));
    }
  }

  void _onSignal(String id, Map<String, dynamic> signal) {
    final kind = signal['kind'] as String? ?? '';
    if (kind == 'restart') return unawaited(_open(id, force: true));
    if (kind == 'bye') {
      if (_link?.id == id) unawaited(_channel?.close());
      return;
    }
    final link = _link;
    if (link == null || link.id != id) return;
    _signalsIn = _signalsIn
        .then((_) async {
          final Map<String, dynamic> payload;
          try {
            payload = await LiveSignalSeal.open(
              link.key,
              id,
              'destination',
              signal,
            );
          } catch (_) {
            return; // tampered, or not sealed under this link's key
          }
          await _channel?.handleSignal(kind, payload);
        })
        .catchError((_) {});
  }

  /// A fresh connection and offer, unless one is already open for [id].
  Future<void> _open(String id, {bool force = false}) async {
    if (!force && _link?.id == id && _channel != null) {
      if (_channel!.open) return;
      final at = _offeredAt;
      if (at != null && DateTime.now().difference(at) < _negotiateFor) return;
    }
    if (_opening) return;
    _opening = true;
    try {
      final userId = _userId;
      final link = userId.isEmpty ? null : await _links.read(userId, id);
      if (link == null) {
        debugPrint('[HistoryLive] no stored link=$id, wake ignored');
        return;
      }
      await _channel?.close();
      final info = await LiveApi(ref.read(apiClientProvider)).link(id);
      final windowStart =
          historyWindowAfterMs(info.windowDays, DateTime.now()) + 1;
      _link = link;
      final channel = LiveChannel(
        onSignal: (kind, payload) => _sendSignal(link, kind, payload),
        onOpen: () => unawaited(_opened(link)),
        onClosed: () => _closed(link),
        answers: (send) => LiveAnswers(
          messages: ref.read(chatMessageStoreProvider),
          blobs: ref.read(attachmentBlobStoreProvider),
          send: send,
          windowStartMs: windowStart,
          open: ref.read(messageVaultProvider).backupBodyOpener(userId),
        ),
      );
      _channel = channel;
      _offeredAt = DateTime.now();
      await channel.start(info.iceServers);
      debugPrint('[HistoryLive] offered link=$id');
    } catch (error) {
      debugPrint('[HistoryLive] open failed: $error');
      await _channel?.close();
    } finally {
      _opening = false;
    }
  }

  Future<void> _opened(LiveLink link) async {
    debugPrint('[HistoryLive] channel open link=${link.id}');
    state = HistoryLiveState(open: true, device: link.device);
    historySyncService(started: true, device: link.device);
    final started = DateTime.now();
    final conversations = await localTransferConversations(ref);
    await _channel?.answers.hello('', conversations).catchError((_) {});
    debugPrint(
      '[HistoryLive] hello convs=${conversations.length} '
      'ms=${DateTime.now().difference(started).inMilliseconds}',
    );
  }

  void _closed(LiveLink link) {
    debugPrint('[HistoryLive] channel closed link=${link.id}');
    if (_link?.id == link.id) _channel = null;
    state = const HistoryLiveState();
    historySyncService(started: false);
  }

  void _sendSignal(LiveLink link, String kind, Map<String, dynamic> payload) {
    final ws = ref.read(wsClientProvider);
    _signalsOut = _signalsOut
        .then((_) async {
          final sealed = await LiveSignalSeal.seal(
            link.key,
            link.id,
            'source',
            kind,
            payload,
          );
          await ws.sendWhenConnected({
            'type': 'history.signal',
            'link_id': link.id,
            'history_signal': sealed,
          });
        })
        .catchError((_) {});
  }
}

final historyLiveProvider =
    NotifierProvider<HistoryLiveNotifier, HistoryLiveState>(
      HistoryLiveNotifier.new,
    );
