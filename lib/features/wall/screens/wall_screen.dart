import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../messages/chat-empty-state/index.dart';
import '../../../core/network/friendly_error.dart';
import '../../messages/providers/team_gate_provider.dart';
import '../providers/wall_provider.dart';
import '../wall-feed/index.dart';

class WallScreen extends ConsumerStatefulWidget {
  const WallScreen({super.key});

  @override
  ConsumerState<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends ConsumerState<WallScreen> {
  var _booted = false;

  @override
  Widget build(BuildContext context) {
    final teamAsync = ref.watch(teamGateProvider);

    return teamAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ),
      error: (error, _) => Scaffold(body: LoadErrorState(error)),
      data: (detail) {
        if (detail == null || !detail.hasTeam) {
          return const Scaffold(
            body: ChatEmptyState(
              title: 'No team yet',
              subtitle:
                  'Join or create a team on the web to use the team wall.',
              icon: Icons.groups_outlined,
            ),
          );
        }
        if (!_booted) {
          _booted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(wallProvider.notifier).bootstrap();
          });
        }
        return WallFeed(isPremium: detail.teamIsPremium);
      },
    );
  }
}
