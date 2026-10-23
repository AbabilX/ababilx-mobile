import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_translations.dart';
import '../../auth/providers/auth_provider.dart';
import 'new_chat_setup.dart';

class NewChatSetupBanner extends ConsumerWidget {
  const NewChatSetupBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newChatSetupProvider);
    final failed = state == NewChatSetupState.failed;
    final signIn = state == NewChatSetupState.needsSignIn;
    final setup = ref.read(newChatSetupProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: signIn
            ? const Icon(Icons.login)
            : failed
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
            signIn
                ? 'sign_in_again_to_continue'
                : failed
                ? 'new_chat_setup_failed'
                : 'new_chat_setup_running',
          ),
        ),
        onTap: signIn
            ? () => setup.signOutToContinue
                  // Signing out keeps this phone's archive and the pending
                  // setup, which finishes after the next sign-in.
                  ? ref.read(authProvider.notifier).signOut()
                  : setup.retry()
            : failed
            ? setup.retry
            : null,
      ),
    );
  }
}
