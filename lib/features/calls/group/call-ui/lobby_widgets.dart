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
    final denied = granted == false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CallRoundButton(
            icon: muted ? CallIcons.micMuted : CallIcons.micOn,
            label: muted ? 'Join unmuted' : 'Join muted',
            tone: muted ? CallButtonTone.active : CallButtonTone.neutral,
            compact: true,
            enabled: !denied,
            onTap: onToggle,
          ),
          const SizedBox(width: 12),
          if (denied)
            TextButton(
              onPressed: onGrant,
              child: const Text(
                'Allow microphone',
                style: TextStyle(color: CallSurface.hand, fontSize: 12),
              ),
            )
          else
            Text(
              muted ? 'You will join muted' : 'Others will hear you',
              style: const TextStyle(color: CallSurface.faint, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class LobbyJoinButton extends StatelessWidget {
  const LobbyJoinButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: CallSurface.accent,
        foregroundColor: const Color(0xFF0B1F14),
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
