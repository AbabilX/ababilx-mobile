import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import 'new_chat_setup.dart';

class NewChatSetupBanner extends ConsumerWidget {
  const NewChatSetupBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(newChatSetupProvider) == NewChatSetupState.failed;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: failed
            ? const Icon(Icons.refresh)
            : const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
        title: Text(
          AppTranslations.translate(
            context,
            ref,
            failed ? 'new_chat_setup_failed' : 'new_chat_setup_running',
          ),
        ),
        onTap: failed ? ref.read(newChatSetupProvider.notifier).retry : null,
      ),
    );
  }
}
