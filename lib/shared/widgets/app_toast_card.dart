import 'dart:async';

import 'package:flutter/material.dart';

const Duration _slide = Duration(milliseconds: 220);

/// The card [showAppToast] drops in from the top: slides down, holds, slides
/// back. A tap anywhere on it dismisses early.
class AppToastCard extends StatefulWidget {
  const AppToastCard({
    super.key,
    required this.message,
    required this.isError,
    required this.visibleFor,
    required this.onGone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool isError;
  final Duration visibleFor;
  final VoidCallback onGone;

  /// A text button at the card's end ("Settings"); pressing it also dismisses.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<AppToastCard> createState() => _AppToastCardState();
}

class _AppToastCardState extends State<AppToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _slide,
  );
  Timer? _hold;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _hold = Timer(widget.visibleFor, _dismiss);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    _leaving = true;
    _hold?.cancel();
    if (mounted) await _controller.reverse();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final background = widget.isError
        ? colors.errorContainer
        : colors.inverseSurface;
    final foreground = widget.isError
        ? colors.onErrorContainer
        : colors.onInverseSurface;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(curve),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_rounded,
                      size: 20,
                      color: foreground,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null) _action(foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(Color foreground) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: TextButton(
      onPressed: () {
        widget.onAction?.call();
        _dismiss();
      },
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(widget.actionLabel!),
    ),
  );
}
