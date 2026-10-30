import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'voice_peer_engine.dart';

/// Same shape as [VoicePeerEngine.new].
typedef VoicePeerEngineFactory =
    VoicePeerEngine Function({
      required VoiceSignalSender sendSignal,
      required void Function() onConnected,
      required void Function(String reason) onFailed,
      required void Function(String reason, {bool immediate}) onTrouble,
      required void Function() onHealthy,
      required void Function(DateTime intervalStart) onMediaFlowing,
      required void Function() onRestartRequested,
      required void Function(bool sharing) onLocalScreenChanged,
      required void Function(MediaStream? stream) onRemoteScreenChanged,
      required void Function(MediaStream? stream, {required bool front})
      onLocalCameraChanged,
      required void Function(MediaStream? stream) onRemoteCameraChanged,
      required bool isOfferer,
    });

/// Builds the media engine for one call.
///
/// Production never overrides this. It exists so the call-ownership tests can
/// prove which call an engine belongs to and whether it was disposed — a real
/// engine needs a microphone and a peer connection, which a test host has not.
final voicePeerEngineFactoryProvider = Provider<VoicePeerEngineFactory>(
  (ref) => VoicePeerEngine.new,
);
