import 'package:flutter/material.dart';

/// The top of the Linked devices screen: an illustration, one sentence, and
/// the button that starts a link.
///
/// Signal's shape, and the reason is the same — the screen answers "how do I
/// get my account onto my laptop?" before it answers "what is already signed
/// in?". The list below is the second question.
///
/// Stays pinned above the device list — it is the common action on this
/// screen, so scrolling it away with a long list made the primary button
/// harder to reach than the rare "sign out others" overflow used to be.
///
/// The drawing is widgets, not an asset: two rounded slabs and three bars.
/// A shipped PNG would need a dark variant, a 3x variant and a designer for
/// every tweak, for something this size.
class DevicesHero extends StatelessWidget {
  const DevicesHero({
    super.key,
    required this.caption,
    required this.buttonLabel,
    required this.onLink,
    required this.signOutOthersLabel,
    this.onSignOutOthers,
  });

  final String caption;
  final String buttonLabel;
  final VoidCallback onLink;

  /// Tooltip / semantics for the circular button beside Link.
  final String signOutOthersLabel;

  /// Null when this phone is the only signed-in session — the circle stays
  /// visible but disabled so the row width does not jump when a peer leaves.
  final VoidCallback? onSignOutOthers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          const _DevicesArt(),
          const SizedBox(height: 24),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onLink,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(buttonLabel),
                ),
              ),
              const SizedBox(width: 12),
              // Right of Link: destructive, rare, one-tap — a labelled red
              // button under the list used to compete with the primary CTA.
              // Same 52px height as the tonal Link pill so the row reads as
              // one control group; always error-tinted so a disabled state
              // (this phone alone) is still recognisable, not invisible.
              SizedBox(
                width: 52,
                height: 52,
                child: IconButton.filledTonal(
                  onPressed: onSignOutOthers,
                  tooltip: signOutOthersLabel,
                  style: IconButton.styleFrom(
                    foregroundColor: colors.error.withValues(
                      alpha: onSignOutOthers == null ? 0.38 : 1,
                    ),
                    backgroundColor: colors.errorContainer.withValues(
                      alpha: onSignOutOthers == null ? 0.38 : 1,
                    ),
                    disabledForegroundColor: colors.error.withValues(
                      alpha: 0.38,
                    ),
                    disabledBackgroundColor: colors.errorContainer.withValues(
                      alpha: 0.38,
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevicesArt extends StatelessWidget {
  const _DevicesArt();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final line = colors.primary;
    final fill = colors.primaryContainer;

    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            child: _Slab(width: 190, height: 128, fill: fill, line: line),
          ),
          Positioned(
            right: 24,
            child: _Slab(width: 62, height: 96, fill: fill, line: line),
          ),
          // The bars read as a conversation moving between the two screens,
          // which is the whole idea of a linked device.
          Positioned(right: 46, top: 26, child: _Bar(width: 96, line: line)),
          Positioned(right: 62, top: 56, child: _Bar(width: 110, line: line)),
          Positioned(right: 52, top: 86, child: _Bar(width: 100, line: line)),
        ],
      ),
    );
  }
}

class _Slab extends StatelessWidget {
  const _Slab({
    required this.width,
    required this.height,
    required this.fill,
    required this.line,
  });

  final double width;
  final double height;
  final Color fill;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line, width: 3),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.line});

  final double width;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 22,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: line, width: 3),
      ),
    );
  }
}
