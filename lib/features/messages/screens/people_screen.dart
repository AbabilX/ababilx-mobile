import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_bar_back_button.dart';
import '../../policy/widgets/policy_gate_overlay.dart';
import '../../settings/settings-hub/settings_row.dart';
import '../providers/chat_connections_provider.dart';

/// Hub: Find people and Connections are separate full screens, not tabs.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(chatConnectionsProvider);
      if (current.connections.isNotEmpty || current.loading) return;
      unawaited(ref.read(chatConnectionsProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final connectionCount = ref
        .watch(chatConnectionsProvider)
        .connections
        .length;
    final connectionsSubtitle = connectionCount > 0
        ? t('chat_connections_count').replaceAll('{n}', '$connectionCount')
        : t('settings_connections_sub');

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          appBar: AppBar(
            leading: const AppBarBackButton(),
            title: Text(t('chat_people')),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsRow(
                icon: HugeIcons.strokeRoundedSearch01,
                title: t('chat_find_people_screen'),
                subtitle: t('settings_find_people_sub'),
                onTap: () => context.push('/messages/people/find'),
              ),
              const Divider(height: 1),
              SettingsRow(
                icon: HugeIcons.strokeRoundedUserGroup,
                title: t('chat_connections'),
                subtitle: connectionsSubtitle,
                onTap: () => context.push('/messages/people/connections'),
              ),
            ],
          ),
        ),
        const PolicyGateOverlay(),
      ],
    );
  }
}
