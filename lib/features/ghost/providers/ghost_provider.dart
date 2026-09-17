import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/ws_client.dart';
import '../../calls/data/models/ice_server.dart';
import '../../messages/message_e2ee/message_vault.dart';
import '../../messages/providers/chat_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../data/ghost_api.dart';
import '../data/ghost_session.dart';
import '../protocol/ghost_file_assembler.dart';
import '../protocol/ghost_frames.dart';
import '../native/ghost_blobs.dart';
import '../webrtc/ghost_file_sender.dart';
import '../webrtc/ghost_peer.dart';
import 'ghost_state.dart';
import 'ghost_temp_files.dart';

part 'ghost_provider_content.dart';
part 'ghost_provider_end.dart';
part 'ghost_provider_link.dart';
part 'ghost_provider_signal.dart';

/// How long an invite rings — the server's `PendingTTL`.
const ghostInviteWindow = Duration(seconds: 60);

/// A drop shorter than this reconnects; longer burns (the user's rule).
const ghostLostGrace = Duration(seconds: 30);

/// Accepted but never connected: the other phone died between the two.
const ghostConnectTimeout = Duration(seconds: 25);

abstract class _GhostBase extends Notifier<GhostState> {
  GhostPeer? _peer;
  GhostFileSender? _sender;
  final _assembler = GhostFileAssembler();
  List<IceServer> _iceServers = const [];
  Future<void> _signalsOut = Future.value();
  Future<void> _signalsIn = Future.value();

  /// Completes once the peer connection exists. An offer can land before the
  /// accept response does, so incoming signals wait on this, never on a null.
  Completer<void> _ready = Completer<void>();
  Timer? _inviteTimer, _connectTimer, _lostTimer, _heartbeat, _backgroundTimer;
  Timer? _typingExpiry;
  DateTime? _typingSentAt;

  GhostApi get _api => ref.read(ghostApiProvider);
  WsClient get _ws => ref.read(wsClientProvider);
  MessageVault get _vault => ref.read(messageVaultProvider);

  String get _selfId {
    final profileId = ref.read(profileProvider).valueOrNull?.id ?? '';
    return profileId.isNotEmpty
        ? profileId
        : ref.read(chatProvider).currentUserId;
  }

  // Implemented by the part mixins; declared here so they can call each other.
  void _sendSignal(String kind, Map<String, dynamic>? payload);
  void _onText(String raw);
  void _onBinary(Uint8List bytes);
  void _lost(String why);
  void _finish(String reason, {required bool byMe, required bool notifyServer});
  void _teardown();
}

/// The one owner of a Ghost Chat on this phone: invite and answer, the peer
/// connection, every message and file, and the burn.
///
/// Every piece of content lives in [GhostState.items] and nowhere else. The
/// class holds no reference to storage, the chat store or the outbox, which is
/// the property worth defending here: a helper that "just caches" something
/// would quietly break the promise the feature is named after.
class GhostNotifier extends _GhostBase
    with _GhostSignal, _GhostLink, _GhostContent, _GhostEnd {
  @override
  GhostState build() {
    final sub = ref.read(wsClientProvider).events.listen(_onEvent);
    ref.onDispose(() {
      unawaited(sub.cancel());
      _teardown();
    });
    return const GhostState();
  }

  /// Invites the DM peer. The composer offers this only in a DM with an
  /// accepted connection; the server enforces the same rule.
  Future<void> invite(String conversationId) async {
    if (state.inSession) return;
    final chat = ref.read(chatProvider);
    final conv = chat.conversationById(conversationId);
    state = GhostState(
      phase: GhostPhase.inviting,
      conversationId: conversationId,
      peerName: conv?.displayTitle(chat.currentUserId) ?? '',
      peerAvatarUrl: conv?.peerUserAvatar,
    );
    try {
      final version = await _vault.ghostKeyVersion(
        conversationId: conversationId,
        currentUserId: _selfId,
      );
      final grant = await _api.start(conversationId, version);
      if (state.phase != GhostPhase.inviting) {
        // Left while the request was in flight: take the invite back down.
        unawaited(_api.finish(grant.session.id, 'cancel').catchError((_) {}));
        return;
      }
      _iceServers = grant.iceServers;
      state = state.copyWith(session: grant.session);
      unawaited(_startPeer(isOfferer: true));
      _inviteTimer = Timer(ghostInviteWindow, _noAnswer);
    } catch (e) {
      final code = e is GhostApiError ? e.code : 'ghost_key_unavailable';
      _finish(
        GhostLocalReason.failed,
        byMe: true,
        notifyServer: false,
        error: code,
      );
    }
  }

  /// The invitee's Join.
  Future<void> accept() async {
    final session = state.session;
    if (state.phase != GhostPhase.invited || session == null) return;
    state = state.copyWith(phase: GhostPhase.accepting);
    try {
      final grant = await _api.accept(session.id);
      _iceServers = grant.iceServers;
      state = state.copyWith(
        session: grant.session,
        phase: GhostPhase.connecting,
      );
      unawaited(_startPeer(isOfferer: false));
      _connectTimer = Timer(
        ghostConnectTimeout,
        () => _lost('connect_timeout'),
      );
    } catch (e) {
      final code = e is GhostApiError ? e.code : 'ghost_chat_failed';
      _finish(
        GhostLocalReason.failed,
        byMe: true,
        notifyServer: false,
        error: code,
      );
    }
  }

  /// The invitee's Decline. Nothing ever existed, so there is no ended screen.
  Future<void> decline() async {
    final session = state.session;
    if (state.phase != GhostPhase.invited || session == null) return;
    _teardown();
    state = const GhostState();
    unawaited(_api.finish(session.id, 'decline').catchError((_) {}));
  }

  /// Dismisses the ended screen.
  void close() {
    if (state.phase == GhostPhase.ended) state = const GhostState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final ghostProvider = NotifierProvider<GhostNotifier, GhostState>(
  GhostNotifier.new,
);
