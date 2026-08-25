import 'dart:io' show Platform;

import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:livekit_client/livekit_client.dart';

import '../../native/android_screen_share.dart';
import '../data/group_call_repository.dart';
import '../data/models/group_call.dart';

/// Screen sharing for group calls — mirrors web `use-group-screen-share.ts`.
///
/// Ownership is server-side (`claim` / `release`) so only one member shares at
/// a time; the LiveKit publish is only started once the claim succeeds, and is
/// rolled back if the OS capture prompt is refused.
class GroupScreenShare {
  GroupScreenShare(this._repository);

  final GroupCallRepository _repository;
  String? _claimedCallId;
  bool _busy = false;

  bool get busy => _busy;

  /// Returns the updated call when the server changed ownership.
  /// Throws on failure so the caller can surface the reason.
  Future<GroupCall?> start(Room room, GroupCall call) async {
    if (_busy) return null;
    _busy = true;
    try {
      final claimed = await _repository.claimScreenShare(call.id);
      _claimedCallId = call.id;
      try {
        // Android needs the MediaProjection consent + a foreground service
        // running before the capturer is allowed to produce frames.
        if (Platform.isAndroid) {
          final granted = await Helper.requestCapturePermission();
          if (!granted) throw StateError('screen capture permission denied');
          await AndroidScreenShare.start();
        }
        await room.localParticipant?.setScreenShareEnabled(true);
      } catch (_) {
        await AndroidScreenShare.stop();
        await _release(call.id);
        rethrow;
      }
      return claimed;
    } finally {
      _busy = false;
    }
  }

  Future<GroupCall?> stop(Room room, GroupCall call) async {
    if (_busy) return null;
    _busy = true;
    try {
      await room.localParticipant?.setScreenShareEnabled(false);
      await AndroidScreenShare.stop();
      return await _release(call.id);
    } finally {
      _busy = false;
    }
  }

  /// LiveKit dropped the capture (user hit the system "Stop sharing"), so the
  /// server-side claim has to be handed back or nobody else could ever share.
  Future<GroupCall?> handleUnpublished(
    TrackSource source,
    GroupCall? call,
  ) async {
    if (source != TrackSource.screenShareVideo || call == null) return null;
    await AndroidScreenShare.stop();
    return _release(call.id);
  }

  /// Another member took the claim while we were still publishing — drop the
  /// local capture so two screens never fight for the stage.
  Future<void> yieldTo(Room room) async {
    _claimedCallId = null;
    await room.localParticipant?.setScreenShareEnabled(false);
    await AndroidScreenShare.stop();
  }

  Future<void> reset() async {
    _claimedCallId = null;
    _busy = false;
    await AndroidScreenShare.stop();
  }

  Future<GroupCall?> _release(String callId) async {
    if (_claimedCallId != callId) return null;
    _claimedCallId = null;
    try {
      return await _repository.releaseScreenShare(callId);
    } catch (_) {
      return null;
    }
  }
}
