import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/chat_message.dart';
import 'group_event_label.dart';

/// Same-day consecutive group system rows fold into one disclosure — same
/// shape as [CallEventsCollapse], until a real chat message breaks the run.
class GroupEventsCollapse extends StatefulWidget {
  const GroupEventsCollapse({
    super.key,
    required this.messages,
    required this.currentUserId,
  });

  final List<ChatMessage> messages;
  final String currentUserId;

  @override
  State<GroupEventsCollapse> createState() => _GroupEventsCollapseState();
}

class _GroupEventsCollapseState extends State<GroupEventsCollapse> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final count = widget.messages.length;
    final chevron = AnimatedRotation(
      turns: _expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 180),
      child: Icon(Icons.expand_more_rounded, size: 16, color: colors.onSurface),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Material(
            color: colors.surfaceContainerHighest,
            elevation: 1,
            shadowColor: colors.shadow.withValues(alpha: 0.18),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: colors.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count group updates',
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    chevron,
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Column(
              children: [
                for (final message in widget.messages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: _GroupEventLine(
                      message: message,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupEventLine extends StatelessWidget {
  const _GroupEventLine({required this.message, required this.currentUserId});

  final ChatMessage message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = groupEventLabel(message, currentUserId);
    final time = _formatClock(message.createdAt);
    final text = time.isEmpty ? label : '$label · $time';

    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _formatClock(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  return DateFormat('h:mm a').format(dt);
}
