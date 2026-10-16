import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../messages/data/models/chat_models.dart';
import '../../../messages/providers/chat_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../call-ui/call_surface.dart';
import '../call-ui/lobby_widgets.dart';
import '../call-ui/ring_picker_sheet.dart';
import '../call_icons.dart';
import '../providers/group_call_provider.dart';

/// The pre-join lobby. Nothing has been joined yet: the call does not know
/// this device exists until Join is pressed, so backing out is free.
class GroupCallLobbyScreen extends ConsumerStatefulWidget {
  const GroupCallLobbyScreen({super.key});

  @override
  ConsumerState<GroupCallLobbyScreen> createState() =>
      _GroupCallLobbyScreenState();
}

class _GroupCallLobbyScreenState extends ConsumerState<GroupCallLobbyScreen> {
  bool? _microphoneGranted;

  /// Who a NEW call may ring: the group minus this account. Null until
  /// loaded; a failed load leaves it null and the row hidden, so the call
  /// rings everyone as it always did.
  List<ChatMember>? _ringable;

  /// The pick. Null = everyone (the server's default, sent as no list).
  Set<String>? _ring;

  @override
  void initState() {
    super.initState();
    unawaited(_checkMicrophone());
    unawaited(_loadRingable());
  }

  Future<void> _loadRingable() async {
    final lobby = ref.read(groupCallProvider).lobby;
    if (lobby == null) return;
    try {
      final members = await ref
          .read(chatProvider.notifier)
          .listChannelMembers(lobby.conversationId);
      final me = ref.read(profileProvider).valueOrNull?.id ?? '';
      if (!mounted) return;
      setState(() => _ringable = members.where((m) => m.userId != me).toList());
    } catch (_) {
      // Best effort: no row, ring everyone.
    }
  }

  Future<void> _pickRing() async {
    final members = _ringable;
    if (members == null || members.isEmpty) return;
    final pick = await showRingPickerSheet(
      context,
      members: members,
      selected: _ring,
    );
    if (pick != null && mounted) setState(() => _ring = pick.ids);
  }

  /// The lobby is the honest moment to ask: before anybody can hear whether
  /// the answer was no.
  Future<void> _checkMicrophone({bool request = false}) async {
    final status = request
        ? await Permission.microphone.request()
        : await Permission.microphone.status;
    if (mounted) setState(() => _microphoneGranted = status.isGranted);
  }

  /// Cancelling only clears the phase; [GroupCallSync] owns popping the route,
  /// so this never navigates itself.
  void _close() => ref.read(groupCallProvider.notifier).cancelLobby();

  @override
  Widget build(BuildContext context) {
    final palette = CallColors.of(context);
    final state = ref.watch(groupCallProvider);
    final lobby = state.lobby;

    if (lobby == null) {
      return Scaffold(backgroundColor: palette.backdrop);
    }

    final active = lobby.call;
    final muted = lobby.joinMuted || _microphoneGranted == false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: palette.backdrop,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Group call',
                      style: TextStyle(color: palette.faint, fontSize: 13),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _close,
                      icon: CallIcon(CallIcons.close, color: palette.onSurface),
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppAvatar(
                        size: 112,
                        url: active?.starterAvatarUrl,
                        name: lobby.conversationName,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        lobby.conversationName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        active == null
                            ? 'Nobody is in this call yet'
                            : '${participantCountLabel(active.participantCount)}'
                                  ' in this call',
                        style: TextStyle(color: palette.faint, fontSize: 14),
                      ),
                      const SizedBox(height: 28),
                      LobbyMicrophoneRow(
                        muted: muted,
                        granted: _microphoneGranted,
                        onToggle: () => ref
                            .read(groupCallProvider.notifier)
                            .setLobbyMuted(!lobby.joinMuted),
                        onGrant: () => _checkMicrophone(request: true),
                      ),
                      // Only a NEW call has anybody to ring; joining one that
                      // is running rings nobody.
                      if (active == null && (_ringable?.isNotEmpty ?? false))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: LobbyRingRow(
                            summary: ringSummary(_ring, _ringable!.length),
                            onTap: () => unawaited(_pickRing()),
                          ),
                        ),
                    ],
                  ),
                ),
                LobbyJoinButton(
                  label: active == null ? 'Start call' : 'Join call',
                  onTap: () => unawaited(
                    ref
                        .read(groupCallProvider.notifier)
                        .join(
                          lobby.conversationId,
                          ring: active == null ? _ring?.toList() : null,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
