import '../../../core/localization/app_translations.dart';
import '../audio/call_audio_output.dart';
import '../group/call_icons.dart';

/// Icons and names for call audio outputs — Signal's `WebRtcAudioOutput`
/// labels and `toFriendlyName`.
CallGlyph callAudioOutputIcon(CallAudioOutput output) => switch (output) {
  CallAudioOutput.handset => CallIcons.speakerOff,
  CallAudioOutput.bluetooth => CallIcons.bluetoothAudio,
  CallAudioOutput.wiredHeadset => CallIcons.wiredHeadset,
  _ => CallIcons.speakerOn,
};

/// The caption under the button.
String callAudioShortLabel(CallAudioOutput output, String lang) =>
    AppTranslations.of(lang, switch (output) {
      CallAudioOutput.handset => 'call_audio_short_earpiece',
      CallAudioOutput.bluetooth => 'call_audio_bluetooth',
      CallAudioOutput.wiredHeadset => 'call_audio_short_headset',
      _ => 'call_control_speaker',
    });

/// A row's name, Signal's `toFriendlyName`: a Bluetooth device by its own name.
String callAudioOptionLabel(CallAudioOption option, String lang) {
  String tr(String key) => AppTranslations.of(lang, key);
  return switch (option.output) {
    CallAudioOutput.handset => tr('call_audio_earpiece'),
    CallAudioOutput.speaker => tr('call_audio_speaker'),
    CallAudioOutput.bluetooth =>
      option.name.isNotEmpty ? option.name : tr('call_audio_bluetooth'),
    CallAudioOutput.wiredHeadset => switch (option.detail) {
      'wired_headphones' => tr('call_audio_wired_headphones'),
      'usb_headset' => tr('call_audio_usb_headset'),
      _ => tr('call_audio_wired_headset'),
    },
    CallAudioOutput.none => option.name,
  };
}
