import 'package:flutter/material.dart';

import '../../../shared/widgets/app_avatar.dart';
import 'call_backdrop.dart';

/// What a call looks like once the window is a thumbnail.
///
/// A floating window is roughly the size of a business card, so the reference
/// app strips its PiP layout to the one thing you glance at — is this still
/// running, and for how long. No controls: the window is too small to hit them
/// reliably, and tapping it restores the full screen where they live.
class PipCallView extends StatelessWidget {
  const PipCallView({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.status,
    this.screenShare,
  });

  final String name;
  final String? avatarUrl;
  final String status;
  final Widget? screenShare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (screenShare != null) {
      return ColoredBox(color: Colors.black, child: screenShare);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CallBackdrop(avatarUrl: avatarUrl, scrim: 0.45, blurSigma: 18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAvatar(size: 44, url: avatarUrl, name: name),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
