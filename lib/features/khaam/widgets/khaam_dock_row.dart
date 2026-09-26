import 'package:flutter/material.dart';

/// The message box: a plain filled capsule, no border, no shadow.
class KhaamSettingRow extends StatelessWidget {
  const KhaamSettingRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}
