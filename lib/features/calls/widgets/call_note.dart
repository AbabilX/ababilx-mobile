import 'package:flutter/material.dart';

/// A one-line notice over the call: what this side is doing, or what failed.
class CallNote extends StatelessWidget {
  const CallNote({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: error ? const Color(0xFFFF8A80) : Colors.white,
          ),
        ),
      ),
    );
  }
}
