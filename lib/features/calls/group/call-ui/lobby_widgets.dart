import 'package:flutter/material.dart';

import '../call_icons.dart';
import 'call_round_button.dart';
import 'call_surface.dart';

/// The two controls the lobby is made of, kept out of the screen file so it
/// stays a single readable flow.
class LobbyMicrophoneRow extends StatelessWidget {
  const LobbyMicrophoneRow({
    super.key,
    required this.muted,
    required this.granted,
    required this.onToggle,
    required this.onGrant,
  });

  final bool muted;
  final bool? granted;
  final VoidCallback onToggle;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final denied = granted == false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CallRoundButton(
            icon: muted ? CallIcons.micMuted : CallIcons.micOn,
            label: muted ? 'Join unmuted' : 'Join muted',
            tone: muted ? CallButtonTone.active : CallButtonTone.neutral,
            diameter: 44,
            enabled: !denied,
            onTap: onToggle,
          ),
          const SizedBox(width: 12),
          if (denied)
            TextButton(
              onPressed: onGrant,
              child: Text(
                'Allow microphone',
                style: TextStyle(color: palette.hand, fontSize: 12),
              ),
            )
          else
            Text(
              muted ? 'You will join muted' : 'Others will hear you',
              style: TextStyle(color: palette.faint, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// "Ring · Everyone ›" — opens the picker of who a new call rings.
class LobbyRingRow extends StatelessWidget {
  const LobbyRingRow({super.key, required this.summary, required this.onTap});

  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    return Material(
      color: palette.tile,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CallIcon(CallIcons.ring, size: 20, color: palette.onSurface),
              const SizedBox(width: 10),
              Text(
                'Ring · $summary',
                style: TextStyle(color: palette.onSurface, fontSize: 14),
              ),
              const SizedBox(width: 6),
              CallIcon(CallIcons.chevron, size: 18, color: palette.faint),
            ],
          ),
        ),
      ),
    );
  }
}

class LobbyJoinButton extends StatelessWidget {
  const LobbyJoinButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: CallColors.of(context).accent,
        foregroundColor: CallColors.of(context).onAccent,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
