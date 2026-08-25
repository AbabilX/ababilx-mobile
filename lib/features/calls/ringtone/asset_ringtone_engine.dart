import 'package:audioplayers/audioplayers.dart';

import '../ringtone_watchdog.dart';
import '../voice_call_log.dart';
import 'ringtone_engine.dart';

/// iOS ring: the bundled asset played through `audioplayers`.
///
/// Android used this too until its ringing moved into a native player; the
/// watchdog stays because `AudioPlayer.state` still lies about playback after
/// an interruption, and position is the only honest signal.
class AssetRingtoneEngine implements RingtoneEngine {
  AssetRingtoneEngine({required Future<void> Function() onStall}) {
    _watchdog = RingtoneWatchdog(
      position: () => _player.getCurrentPosition(),
      playing: () => _playing,
      restart: onStall,
      onStall: (position) => voiceCallLog(
        'ringtone.stalled',
        reason: 'position=${position?.inMilliseconds ?? -1}ms',
      ),
    );
  }

  static const _asset = 'ringtone/Clear_Agenda.mp3';

  final _player = AudioPlayer(playerId: 'ababilx_call_ringtone');
  late final RingtoneWatchdog _watchdog;
  bool _playing = false;

  @override
  bool get replayOnHandoff => true;

  @override
  Future<bool> start() async {
    for (final context in [_ringContext, null]) {
      try {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource(_asset), volume: 1, ctx: context);
        _watchdog.reset();
        _playing = true;
        return true;
      } catch (error) {
        voiceCallLog(
          'ringtone.play.failed',
          source: context == null ? 'default_context' : 'ring_context',
          reason: '$error',
        );
      }
    }
    _playing = false;
    return false;
  }

  @override
  Future<bool> restart() async {
    await stop();
    return start();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {
      // A missing audio route must never take the call dialog down with it.
    }
  }

  @override
  void guard({required bool wanted, required bool playing}) {
    _playing = playing;
    if (wanted) {
      _watchdog.start();
    } else {
      _watchdog.stop();
    }
  }

  /// Route to the loudspeaker — an incoming call must be audible across the
  /// room — but request **no** audio focus: audioplayers answers a focus loss
  /// by pausing the native player behind Dart's back, so any competing ringer
  /// or notification would silence the call tone for good. Mixing over other
  /// audio is the lesser evil. Some OEMs reject these attributes outright,
  /// which is why [start] retries with the default context.
  AudioContext get _ringContext => AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.notificationRingtone,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.duckOthers},
    ),
  );
}
