import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/chat_message.dart';
import '../voice_call_message_label.dart';

/// Same-day consecutive call rows fold into one disclosure — mirrors web
/// `chat-timeline/call-events-collapse.tsx`.
class CallEventsCollapse extends StatefulWidget {
  const CallEventsCollapse({
    super.key,
    required this.messages,
    required this.currentUserId,
  });

  final List<ChatMessage> messages;
  final String currentUserId;

  @override
  State<CallEventsCollapse> createState() => _CallEventsCollapseState();
}

class _CallEventsCollapseState extends State<CallEventsCollapse> {
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
                      Icons.call_outlined,
                      size: 14,
                      color: colors.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count call events',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final message in widget.messages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: _CallEventLine(
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

class _CallEventLine extends StatelessWidget {
  const _CallEventLine({required this.message, required this.currentUserId});

  final ChatMessage message;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final time = _formatClock(message.createdAt);

    if (message.isGroupCall) {
      return _line(
        icon: Icons.headset_mic_outlined,
        color: colors.onSurfaceVariant,
        text: time.isEmpty ? 'Group call ended' : 'Group call ended · $time',
        textTheme: textTheme,
      );
    }

    final missed = isMissedStyleVoiceCall(message, currentUserId);
    final mode = message.meta?['mode'] as String?;
    final icon = switch (mode) {
      'screen' => Icons.screen_share_outlined,
      'video' => Icons.videocam_outlined,
      _ => Icons.call_outlined,
    };
    final label = _historyLabel(message, currentUserId);
    return _line(
      icon: icon,
      color: missed ? colors.error : colors.onSurfaceVariant,
      text: time.isEmpty ? label : '$label · $time',
      textTheme: textTheme,
    );
  }

  Widget _line({
    required IconData icon,
    required Color color,
    required String text,
    required TextTheme textTheme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }
}

String _formatClock(String iso) {
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  return DateFormat('h:mm a').format(dt);
}

/// Expanded line: Incoming/Outgoing, no duration. Kept here so the widget
/// does not depend on a newly-added export (hot-restart incremental cache).
String _historyLabel(ChatMessage message, String currentUserId) {
  final status = (message.meta?['status'] as String?) ?? '';
  if (status != 'ended') {
    return voiceCallMessageLabel(message, currentUserId);
  }
  final callerId = (message.meta?['caller_id'] as String?) ?? message.userId;
  final isCaller = currentUserId.isNotEmpty && currentUserId == callerId;
  final mode = message.meta?['mode'] as String?;
  final noun = switch (mode) {
    'screen' => 'screen share',
    'video' => 'video call',
    _ => 'voice call',
  };
  return isCaller ? 'Outgoing $noun' : 'Incoming $noun';
}
