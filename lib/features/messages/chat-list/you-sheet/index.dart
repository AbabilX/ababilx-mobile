import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/providers/profile_provider.dart';
import 'you_identity.dart';
import 'you_menu.dart';
import 'you_photo_cta.dart';
import 'you_sheet_bar.dart';
import 'you_status_field.dart';

Future<void> showYouSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => const YouSheet(),
  );
}

class YouSheet extends ConsumerWidget {
  const YouSheet({super.key});

  void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

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
              const YouSheetBar(),
              YouIdentity(name: name, avatarUrl: avatar),
              YouPhotoCta(onTap: () => _soon(context, 'Profile photo')),
              YouStatusField(onTap: () => _soon(context, 'Status')),
              const YouMenu(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
