import 'package:flutter/material.dart';
import 'package:ababilx/shared/widgets/app_bar_back_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../core/network/friendly_error.dart';
import '../../privacy-mode/privacy_mode_provider.dart';
import '../discovery/discovery_identity_section.dart';
import '../discovery/discovery_provider.dart';
import '../typing-indicators/typing_indicators_tile.dart';

/// How people can find you in search.
///
/// This is the mobile half of `/user/settings` → Discovery on the web.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(discoveryProvider);
    final theme = Theme.of(context);
    // Privacy mode overrides all three switches while it is on. Their stored
    // values are kept, and apply again once it is off, so they are drawn off
    // and locked here rather than written.
    final private = ref.watch(privacyModeProvider);
    ValueChanged<bool>? unlessPrivate(ValueChanged<bool> apply) =>
        private ? null : apply;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBarBackButton(),
        title: const Text('Discovery'),
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: LoadErrorState(error)),
        data: (data) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Anyone who finds you can start a chat. You still get to '
                'accept, delete or block it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (private)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  AppTranslations.translate(
                    context,
                    ref,
                    'privacy_mode_discovery_locked',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const DiscoveryIdentitySection(),
            const Divider(height: 24),
            _Toggle(
              title: 'Find me by username',
              subtitle:
                  'Someone has to type your full username — a partial '
                  'one finds nobody.',
              value: data.byUsername && !private,
              onChanged: unlessPrivate(
                (v) => ref
                    .read(discoveryProvider.notifier)
                    .setToggle(byUsername: v),
              ),
            ),
            _Toggle(
              title: 'Find me by email',
              subtitle: 'Exact match only — someone has to know the address.',
              value: data.byEmail && !private,
              onChanged: unlessPrivate(
                (v) =>
                    ref.read(discoveryProvider.notifier).setToggle(byEmail: v),
              ),
            ),
            // No phone number here at all: phone search is paused on
            // mobile (numbers are never verified).
            const Divider(height: 24),
            const TypingIndicatorsTile(),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
