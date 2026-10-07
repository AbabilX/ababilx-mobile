import 'package:flutter/material.dart';

/// The sender's name over the first incoming bubble of a run in a group, with
/// their member tag beside it.
class MessageSenderLabel extends StatelessWidget {
  const MessageSenderLabel({
    super.key,
    required this.name,
    required this.tag,
    required this.color,
    required this.onTap,
  });

  final String name;
  final String tag;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tag.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                tag,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
