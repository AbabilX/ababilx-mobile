/// Where a call's audio is going — Signal's `WebRtcAudioOutput` plus
/// [none] for "nothing reported yet".
enum CallAudioOutput { handset, speaker, bluetooth, wiredHeadset, none }

CallAudioOutput callAudioOutputFromWire(Object? wire) => switch (wire) {
  'handset' => CallAudioOutput.handset,
  'speaker' => CallAudioOutput.speaker,
  'bluetooth' => CallAudioOutput.bluetooth,
  'wired' => CallAudioOutput.wiredHeadset,
  _ => CallAudioOutput.none,
};

String callAudioOutputToWire(CallAudioOutput output) => switch (output) {
  CallAudioOutput.handset => 'handset',
  CallAudioOutput.speaker => 'speaker',
  CallAudioOutput.bluetooth => 'bluetooth',
  CallAudioOutput.wiredHeadset => 'wired',
  CallAudioOutput.none => 'none',
};

/// One row of the picker — Signal's `AudioOutputOption`. [id] goes back to
/// native unchanged; [name] is the product name (a Bluetooth row shows it);
/// [detail] tells a wired row apart: `wired_headphones`, `wired_headset`,
/// `usb_headset`.
class CallAudioOption {
  const CallAudioOption({
    required this.output,
    required this.id,
    this.name = '',
    this.detail = '',
  });

  factory CallAudioOption.fromMap(Map<Object?, Object?> map) => CallAudioOption(
    output: callAudioOutputFromWire(map['type']),
    id: (map['id'] as num?)?.toInt() ?? -1,
    name: map['name'] as String? ?? '',
    detail: map['detail'] as String? ?? '',
  );

  final CallAudioOutput output;
  final int id;
  final String name;
  final String detail;
}

/// What the call is on, and what it could be on, as the native audio owner
/// last reported it. Empty on iOS and outside a call.
class CallAudioDevices {
  const CallAudioDevices({
    this.active = CallAudioOutput.none,
    this.activeId = -1,
    this.options = const [],
  });

  factory CallAudioDevices.fromMap(Map<Object?, Object?> map) =>
      CallAudioDevices(
        active: callAudioOutputFromWire(map['active']),
        activeId: (map['activeId'] as num?)?.toInt() ?? -1,
        options: [
          for (final option in (map['options'] as List<Object?>? ?? const []))
            if (option is Map) CallAudioOption.fromMap(option),
        ],
      );

  static const empty = CallAudioDevices();

  /// Signal's `SHOW_PICKER_THRESHOLD`: with fewer choices the button cycles.
  static const pickerThreshold = 3;

  final CallAudioOutput active;
  final int activeId;
  final List<CallAudioOption> options;

  bool get known => options.isNotEmpty;

  /// Signal's `willDisplayPicker`: three or more outputs, or no earpiece to
  /// fall back to — then a press opens the list instead of cycling.
  bool get willDisplayPicker =>
      known &&
      (options.length >= pickerThreshold ||
          !options.any((o) => o.output == CallAudioOutput.handset));

  /// The output a cycling press moves to: the one after the current, or —
  /// when the current is unknown — the first that is not it (Signal's
  /// `cycleToNextDevice`).
  CallAudioOption? get next {
    if (!known) return null;
    final index = options.indexWhere((o) => o.id == activeId);
    if (index >= 0) return options[(index + 1) % options.length];
    return options.firstWhere(
      (o) => o.output != active,
      orElse: () => options.first,
    );
  }
}
