import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/providers/profile_provider.dart';
import 'you_identity.dart';
import 'you_menu.dart';
import 'you_sheet_action.dart';

Future<YouSheetAction?> showYouSheet(BuildContext context) {
  return showModalBottomSheet<YouSheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const YouSheet(),
  );
}

class YouSheet extends ConsumerWidget {
  const YouSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final user = ref.watch(profileProvider).valueOrNull;
    final name = user?.name.isNotEmpty == true ? user!.name : 'You';
    final avatar = user?.avatarUrl;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              YouIdentity(
                name: name,
                currentUserId: user?.id ?? '',
                avatarUrl: avatar,
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const YouMenu(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
