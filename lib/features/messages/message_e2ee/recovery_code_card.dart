import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a recovery code and the one way to keep it on a phone.
///
/// Nothing anywhere stores this string — not the server, not this device — so
/// the screen it appears on is the only chance to save it. Selectable text as
/// well as a copy button, because a password manager and a hand-written note
/// fail differently and some people want both.
class RecoveryCodeCard extends StatefulWidget {
  const RecoveryCodeCard({super.key, required this.code});
  final String code;

  @override
  State<RecoveryCodeCard> createState() => _RecoveryCodeCardState();
}

class _RecoveryCodeCardState extends State<RecoveryCodeCard> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            widget.code,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              height: 1.7,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _copy,
            icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
            label: Text(_copied ? 'Copied' : 'Copy code'),
          ),
        ),
      ],
    );
  }
}
