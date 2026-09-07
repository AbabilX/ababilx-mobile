import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/root_back.dart';
import '../../native/android_call_screen_lock.dart';
import '../../native/android_pip.dart';
import '../../widgets/pip_call_view.dart';
import '../call-ui/call_stage_view.dart';
import '../call-ui/call_surface.dart';
import '../call-ui/group_call_header.dart';
import '../call-ui/group_call_stage.dart';
import '../call-ui/participants_sheet.dart';
import '../call-ui/reaction_burst.dart';
import '../providers/group_call_provider.dart';
import '../widgets/group_call_controls.dart';

/// Full-screen group call: header, stage (grid, speaker or a shared screen),
/// floating reactions and the control bar. Always dark, like every call
/// surface in the app.
class GroupCallScreen extends ConsumerStatefulWidget {
  const GroupCallScreen({super.key});

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen> {
  CallStageView _view = CallStageView.grid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AndroidPip.setActive(true);
    });
    AndroidCallScreenLock.setKeepScreenOn(true);
  }

  @override
  void dispose() {
    AndroidPip.setActive(false);
    AndroidCallScreenLock.setKeepScreenOn(false);
    super.dispose();
  }

  /// Back shrinks the call into a floating window rather than leaving it
  /// running with nothing on screen; the ordinary pop is the fallback for
  /// devices that refuse to shrink.
  Future<void> _minimize() async {
    if (await AndroidPip.enter()) return;
    if (mounted) popOrGoHome(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupCallProvider);

    return ValueListenableBuilder<bool>(
      valueListenable: AndroidPip.inPip,
      builder: (context, inPip, _) {
        if (inPip) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: PipCallView(
              name: state.title,
              avatarUrl: null,
              status: '${state.participants.length} in call',
            ),
          );
        }
        return PopScope(
          canPop: state.phase != GroupCallPhase.connected,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _minimize();
          },
          child: _body(state),
        );
      },
    );
  }

  Widget _body(GroupCallState state) => Scaffold(
    backgroundColor: CallColors.of(context).backdrop,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            GroupCallHeader(
              state: state,
              view: _view,
              onView: (next) => setState(() => _view = next),
              onParticipants: () => showParticipantsSheet(context, state),
              onMinimize: _minimize,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: state.phase == GroupCallPhase.joining
                        ? const _Joining()
                        : GroupCallStage(state: state, view: _view),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 200,
                    child: ReactionBurst(reactions: state.reactions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GroupCallControls(state: state),
          ],
        ),
      ),
    ),
  );
}

class _Joining extends StatelessWidget {
  const _Joining();

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: palette.accent),
          const SizedBox(height: 16),
          Text('Joining group call…', style: TextStyle(color: palette.faint)),
        ],
      ),
    );
  }
}
