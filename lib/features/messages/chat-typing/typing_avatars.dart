import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../chat-timeline/signal_bubble_metrics.dart';
import '../data/models/chat_models.dart';
import '../nickname/contact_nickname_provider.dart';
import 'chat_typing_provider.dart';

/// Faces of whoever is typing in a group, overlapped like Signal's group
/// indicator, sitting in the same gutter an incoming group message's avatar
/// uses. A typing frame carries only an id and a name, so the picture comes
/// from that person's newest message on screen; nobody's message loaded
/// means an initial, same as [AppAvatar] draws anywhere else.
class TypingAvatars extends ConsumerWidget {
  const TypingAvatars({
    super.key,
    required this.typists,
    required this.messages,
    required this.ring,
  });

  final Map<String, Typist> typists;
  final List<ChatMessage> messages;

  /// Separates overlapped faces; the timeline's own background.
  final Color ring;

  static const _max = 3;
  static const _size = SignalBubbleMetrics.avatarSize;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nicknames = ref.watch(contactNicknamesProvider);
    final ids =
        (typists.entries.toList()
              ..sort((a, b) => a.value.at.compareTo(b.value.at)))
            .map((e) => e.key)
            .take(_max)
            .toList();
    final faces = [
      for (final id in ids)
        _Face(
          url: _avatarOf(id),
          name: nicknames.resolve(userId: id, name: typists[id]!.name),
        ),
    ];
    final width = _size + (faces.length - 1) * (_size - _overlap);
    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = faces.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: faces.length > 1
                      ? Border.all(color: ring, width: 1.5)
                      : null,
                ),
                child: ClipOval(
                  child: AppAvatar(
                    size: faces.length > 1 ? _size - 3 : _size,
                    url: faces[i].url,
                    name: faces[i].name,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// [messages] is newest-last, so the scan runs backwards.
  String? _avatarOf(String userId) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.userId == userId && (m.userAvatarUrl ?? '').isNotEmpty) {
        return m.userAvatarUrl;
      }
    }
    return null;
  }
}

class _Face {
  const _Face({required this.url, required this.name});
  final String? url;
  final String name;
}
