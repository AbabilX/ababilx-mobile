import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/network/ws_client.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../native/android_group_call_ui.dart';
import '../data/group_call_api.dart';
import '../data/group_call_repository.dart';
import '../data/models/group_call.dart';
import 'group_call_errors.dart';
import 'group_call_invites.dart';
import 'group_call_state.dart';
import 'group_room_binding.dart';
import 'group_room_snapshot.dart';
import 'group_screen_share.dart';

export 'group_call_state.dart';

part 'group_call_callkit.dart';
part 'group_call_lifecycle.dart';
part 'group_call_media.dart';
part 'group_call_ws.dart';

/// Shared state for the group-call notifier, split across `part` files so no
/// single file carries the whole SFU lifecycle.
abstract class GroupCallBase extends Notifier<GroupCallState> {
  Room? _room;
  GroupRoomBinding? _binding;
  GroupScreenShare? _screenShare;
  GroupCallInvites? _invites;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  StreamSubscription<CallEvent?>? _nativeSub;
  bool _booted = false;
  bool _joinPending = false;
  final Set<String> _leftCallIds = {};
  String _currentUserId = '';

  GroupCallRepository get _repository => ref.read(groupCallRepositoryProvider);
  WsClient get _ws => ref.read(wsClientProvider);
}

/// Channel group calls over the LiveKit SFU.
///
/// Deliberately separate from `voiceCallProvider` (1:1 DM peer-to-peer WebRTC):
/// the two systems share only the ringtone, exactly as on web.
class GroupCallNotifier extends GroupCallBase
    with GroupCallLifecycle, GroupCallMedia, GroupCallWs, GroupCallCallkit {
  @override
  GroupCallState build() {
    ref.onDispose(() => unawaited(_teardown()));
    _currentUserId = ref.read(profileProvider).valueOrNull?.id ?? '';
    ref.listen(profileProvider, (_, next) {
      final id = next.valueOrNull?.id;
      if (id != null && id.isNotEmpty) _currentUserId = id;
    });
    _invites = GroupCallInvites(
      onChanged: (invite) {
        state = invite == null
            ? state.copyWith(clearInvite: true)
            : state.copyWith(invite: invite);
        unawaited(syncNativeInviteUi());
      },
    );
    _screenShare = GroupScreenShare(_repository);
    return const GroupCallState();
  }

  Future<void> bootstrap() async {
    if (_booted) return;
    _booted = true;
    initNativeCallUi();
    _wsSub = _ws.events.listen(handleWsEvent);
    // A CallKit "Join" from a killed app relaunches the process — pick that up
    // before the socket, which may take a moment to connect.
    await recoverNativeAccept();
    await _ws.connect();
  }

  /// Best-effort discovery for the channel header; join re-checks server-side.
  Future<void> refresh(String conversationId) async {
    try {
      rememberActiveCall(
        conversationId,
        await _repository.active(conversationId),
      );
    } catch (_) {
      // Header discovery is best-effort.
    }
  }

  @override
  Future<void> join(String conversationId) async {
    if (_joinPending || _room != null) return;
    _joinPending = true;
    _invites?.dismiss();
    state = state.copyWith(
      phase: GroupCallPhase.joining,
      clearCall: true,
      clearScreen: true,
      participants: const [],
      clearError: true,
      microphoneUnavailable: false,
      sharingScreen: false,
    );
    GroupCall? call;
    try {
      final session = await _repository.join(conversationId);
      call = session.call;
      _leftCallIds.remove(call.id);
      _invites?.markAnswered(call.id);
      await AndroidGroupCallUi.hideIncoming(call.id);
      // Ongoing-call notification + `phoneCall|microphone` foreground service,
      // so Android keeps the SFU connection alive once the app leaves screen.
      await AndroidGroupCallUi.startOngoing(call);
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      state = state.copyWith(call: call);
      rememberActiveCall(conversationId, call);
      _bind(room);
      await room.connect(session.serverUrl, session.participantToken);
      final micOn = await enableMicrophone(room);
      await AudioManager.instance.setSpeakerOutputPreferred(true);
      if (_room != room) return;
      state = state.copyWith(
        phase: GroupCallPhase.connected,
        microphoneUnavailable: !micOn,
        speaker: true,
      );
      syncRoom();
    } catch (error) {
      await clearRoom(error: groupCallErrorMessage(error));
      if (call != null) unawaited(leaveOnce(call.id));
    } finally {
      _joinPending = false;
    }
  }

  @override
  Future<void> leave() async {
    final call = state.call;
    await clearRoom();
    if (call != null) await leaveOnce(call.id);
  }

  void acceptInvite() {
    final invite = state.invite;
    if (invite != null) unawaited(join(invite.conversationId));
  }

  /// Local-only: silences this device, the call keeps running for everyone else.
  void declineInvite() => _invites?.dismiss();

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> shutdown() async {
    await _teardown();
    state = const GroupCallState();
  }

  void _bind(Room room) {
    _binding = GroupRoomBinding.attach(
      room,
      sync: syncRoom,
      onDisconnected: () => unawaited(onRoomDisconnected(room)),
      onLocalTrackUnpublished: (source) =>
          unawaited(onLocalTrackUnpublished(source)),
    );
  }

  Future<void> _teardown() async {
    await _wsSub?.cancel();
    _wsSub = null;
    _booted = false;
    await disposeNativeCallUi();
    final invite = state.invite;
    if (invite != null) await AndroidGroupCallUi.hideIncoming(invite.id);
    _invites?.dispose();
    await clearRoom();
  }
}

final groupCallProvider = NotifierProvider<GroupCallNotifier, GroupCallState>(
  GroupCallNotifier.new,
);

/// The live call in a channel, if any — drives the conversation header button.
final activeGroupCallProvider = Provider.family<GroupCall?, String>(
  (ref, conversationId) => ref.watch(groupCallProvider).callFor(conversationId),
);
