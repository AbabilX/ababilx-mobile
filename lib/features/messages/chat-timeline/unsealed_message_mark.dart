import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../chat_icon.dart';
import '../data/models/chat_models.dart';
import '../message_e2ee/unsealed_message.dart';

/// "Not encrypted", under a text message that reached a sealed chat without
/// being sealed (see [isUnsealedText]). Draws nothing for every other row,
/// which is nearly all of them.
///
/// The app never sends such a row, so the name on it proves nothing: it was
/// written into the database, or by the server itself. It is marked and not
/// hidden, so nothing the user was really sent ever disappears.
class UnsealedMessageMark extends ConsumerWidget {
  const UnsealedMessageMark({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Decided before the provider is touched: a sealed row never asks.
    if (message.isEncrypted || message.isPending) {
      return const SizedBox.shrink();
    }
    final after = ref.watch(
      unsealedAfterProvider(
        message.conversationId,
      ).select((line) => line.valueOrNull),
    );
    if (!isUnsealedText(message, after)) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final ink = colors.onErrorContainer;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: colors.errorContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _explain(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatIcon(
                  HugeIcons.strokeRoundedSquareUnlock02,
                  size: 13,
                  color: ink,
                ),
                const SizedBox(width: 6),
                Text(
                  'Not encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _explain(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final colors = Theme.of(sheet).colorScheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'This message was not encrypted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                'Messages in this chat are end-to-end encrypted. This one '
                'reached your phone without encryption, so AbabilX cannot '
                'confirm who wrote it.\n\n'
                'Do not act on it until you have checked with the person '
                'another way.',
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
