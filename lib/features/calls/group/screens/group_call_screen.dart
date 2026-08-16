import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/root_back.dart';
import '../providers/group_call_provider.dart';
import '../widgets/group_call_controls.dart';
import '../widgets/group_participant_grid.dart';
import '../widgets/group_screen_stage.dart';

/// Full-screen group call — participant grid, or the screen share on stage
/// with the participants as a filmstrip. Mirrors web `group-call-overlay.tsx`.
class GroupCallScreen extends ConsumerWidget {
  const GroupCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(groupCallProvider);
    final colors = Theme.of(context).colorScheme;

    // Back minimizes rather than hangs up (same as the DM call screen): the
    // call keeps running and the channel header offers the way back in.
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            children: [
              _Header(state: state),
              const SizedBox(height: 12),
              Expanded(
                child: state.phase == GroupCallPhase.joining
                    ? const _Joining()
                    : _Stage(state: state),
              ),
              const SizedBox(height: 12),
              GroupCallControls(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final GroupCallState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final subtitle = state.phase == GroupCallPhase.joining
        ? 'Joining…'
        : '${state.participants.length} in call';

    return Row(
      children: [
        IconButton(
          tooltip: 'Minimize call',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => popOrGoHome(context),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                state.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // Balances the leading icon so the title stays optically centred.
        const SizedBox(width: 48),
      ],
    );
  }
}

class _Joining extends StatelessWidget {
  const _Joining();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          'Joining group call…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _Stage extends StatelessWidget {
  const _Stage({required this.state});
  final GroupCallState state;

  @override
  Widget build(BuildContext context) {
    final screen = state.screen;
    if (screen == null) {
      return GroupParticipantGrid(participants: state.participants);
    }
    return Column(
      children: [
        Expanded(child: GroupScreenStage(screen: screen)),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: GroupParticipantGrid(
            participants: state.participants,
            compact: true,
          ),
        ),
      ],
    );
  }
}
