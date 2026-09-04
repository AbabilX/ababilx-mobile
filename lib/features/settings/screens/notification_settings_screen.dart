import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/root_back.dart';
import '../../notifications/providers/fcm_provider.dart';
import '../../notifications/providers/battery_optimization_provider.dart';
import '../../notifications/widgets/battery_optimization_tile.dart';
import '../../notifications/widgets/data_saver_tile.dart';
import '../../notifications/widgets/notification_permission_tile.dart';
import '../settings-hub/settings_row.dart';

/// Notification settings.
///
/// Per-channel toggles live in the Android system UI, not here — the app
/// creates its channels (chat, calls, standup, AI) and Android owns their
/// sound and importance from that point on. Duplicating them in-app would show
/// a switch that the OS can silently disagree with, so this screen states
/// permission status and hands off.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every row on this screen is answered in a system settings screen, so
  /// coming back is exactly when what it says goes stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(batteryRestrictionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = ref.watch(notificationPermissionProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: const [
                NotificationPermissionTile(),
                BatteryOptimizationTile(),
                DataSaverTile(),
              ],
            ),
          ),
          if (granted == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications are allowed for this device.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          SettingsRow(
            icon: HugeIcons.strokeRoundedNotification03,
            title: 'System notification settings',
            subtitle: 'Sound, importance and per-channel controls',
            onTap: openAppSettings,
          ),
        ],
      ),
    );
  }
}
