import 'package:flutter/material.dart';

import '../../../core/localization/app_translations.dart';
import '../audio/call_audio_output.dart';
import '../audio/call_audio_route.dart';
import 'call_audio_labels.dart';

export 'call_audio_labels.dart';

/// The audio-output button's behaviour — Signal's `CallAudioToggleButton` +
/// `WebRtcAudioPicker31`: with fewer than three outputs and an earpiece among
/// them a press cycles to the next one; otherwise it opens the "Audio output"
/// sheet. Before the native list exists (iOS, or the first instant of a call)
/// it is the old speaker switch, [fallback].
Future<void> pressCallAudioOutput(
  BuildContext context,
  CallAudioDevices devices, {
  required String lang,
  required Future<void> Function() fallback,
}) async {
  if (!devices.known) return fallback();
  if (!devices.willDisplayPicker) {
    final next = devices.next;
    if (next != null) await CallAudioRoute.select(next);
    return;
  }
  final picked = await showModalBottomSheet<CallAudioOption>(
    context: context,
    showDragHandle: true,
    builder: (_) => CallAudioOutputSheet(devices: devices, lang: lang),
  );
  if (picked != null) await CallAudioRoute.select(picked);
}

/// What the button shows: the current output, and a drop-down mark when a
/// press opens the list.
class CallAudioButtonFace {
  const CallAudioButtonFace({
    required this.output,
    required this.selected,
    required this.dropdown,
  });

  factory CallAudioButtonFace.of(
    CallAudioDevices devices, {
    required bool speaker,
  }) {
    if (!devices.known) {
      return CallAudioButtonFace(
        output: speaker ? CallAudioOutput.speaker : CallAudioOutput.handset,
        selected: speaker,
        dropdown: false,
      );
    }
    final picker = devices.willDisplayPicker;
    // The icon is where the sound is now. Signal keeps the speaker glyph on
    // a two-way switch and only tints it; on our deck that read as a button
    // that did nothing.
    final output = devices.active == CallAudioOutput.none
        ? (speaker ? CallAudioOutput.speaker : CallAudioOutput.handset)
        : devices.active;
    return CallAudioButtonFace(
      output: output,
      selected: !picker && devices.active == CallAudioOutput.speaker,
      dropdown: picker,
    );
  }

  final CallAudioOutput output;
  final bool selected;
  final bool dropdown;
}

/// Signal's `WebRtcAudioOutputBottomSheet`: "Audio output", then one radio
/// row per output — radio, icon, name. Pops with the row pressed.
class CallAudioOutputSheet extends StatelessWidget {
  const CallAudioOutputSheet({
    super.key,
    required this.devices,
    required this.lang,
  });

  final CallAudioDevices devices;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                AppTranslations.of(lang, 'call_audio_output'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            for (final option in devices.options)
              _OutputRow(
                option: option,
                label: callAudioOptionLabel(option, lang),
                selected: option.id == devices.activeId,
              ),
          ],
        ),
      ),
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({
    required this.option,
    required this.label,
    required this.selected,
  });

  final CallAudioOption option;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(option),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Icon(
                  callAudioOutputIcon(option.output),
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
