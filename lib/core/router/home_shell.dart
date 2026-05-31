import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/app_translations.dart';
import '../storage/plan_expired_storage.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../shared/widgets/plan_expired_dialog.dart';

/// Bottom navigation shell wrapping Rules and Profile tabs.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool _planExpiredChecked = false;

  static const _tabs = ['/home', '/rules', '/auto-commit', '/profile'];

  Future<void> _maybeShowPlanExpiredDialog() async {
    final user = ref.read(profileProvider).valueOrNull;
    if (user == null || !user.showPlanExpiredDialog || _planExpiredChecked) {
      return;
    }
    final dismissed = await isPlanExpiredDialogDismissed(
      user.id,
      user.premiumUntil,
    );
    if (!mounted || dismissed) {
      setState(() => _planExpiredChecked = true);
      return;
    }
    setState(() => _planExpiredChecked = true);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PlanExpiredDialog(
        user: user,
        onDismiss: () async {
          await dismissPlanExpiredDialog(user.id, user.premiumUntil);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    ref.listen(profileProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user?.showPlanExpiredDialog == true) {
        _planExpiredChecked = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowPlanExpiredDialog();
        });
      }
    });

    if (profile.hasValue && !_planExpiredChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowPlanExpiredDialog();
      });
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outline, width: 0.8),
          ),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: AppTranslations.translate(context, ref, 'home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.schedule_send_outlined),
              selectedIcon: const Icon(Icons.schedule_send_rounded),
              label: AppTranslations.translate(context, ref, 'rules'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.commit_rounded),
              selectedIcon: const Icon(Icons.commit_rounded),
              label: AppTranslations.translate(context, ref, 'auto_commit'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: AppTranslations.translate(context, ref, 'profile'),
            ),
          ],
        ),
      ),
    );
  }
}
