import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/localization/app_translations.dart';
import '../../shared/widgets/app_toast.dart';
import '../messages/chat-details/details_tile.dart';
import '../messages/chat_icon.dart';
import '../messages/providers/chat_provider.dart';
import 'private_chat_sheet.dart';
import 'private_chat_state.dart';

/// "Private chat" on a DM's details screen (server 0160). Either person can
/// switch it and it binds both, so the value line says who holds it when it
/// was the other side — a switch that reads "on" nobody here touched would
/// look like a fault.
class PrivateChatTile extends ConsumerStatefulWidget {
  const PrivateChatTile({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<PrivateChatTile> createState() => _PrivateChatTileState();
}

class _PrivateChatTileState extends ConsumerState<PrivateChatTile> {
  bool _busy = false;

  String _t(String key) => AppTranslations.translate(context, ref, key);

  Future<void> _set(bool on) async {
    if (_busy || !await confirmPrivateChat(context, ref, turnOn: on)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(privateChatOverridesProvider.notifier)
          .set(widget.conversationId, on, ref.read(chatProvider).currentUserId);
    } on DioException catch (e) {
      final code = e.response?.data is Map ? e.response?.data['error'] : null;
      if (mounted) {
        showAppToast(
          context,
          _t(
            code == 'connection_required'
                ? 'private_chat_needs_connection'
                : 'dm_setting_failed',
          ),
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, _t('dm_setting_failed'), isError: true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      conversationPrivateChatProvider(widget.conversationId),
    );
    final me = ref.watch(chatProvider.select((s) => s.currentUserId));
    final value = !state.enabled
        ? _t('private_chat_off')
        : state.by.isNotEmpty && state.by != me
        ? _t('private_chat_on_them')
        : _t('private_chat_on');
    return DetailsTile(
      icon: const ChatIcon(HugeIcons.strokeRoundedIncognito),
      title: _t('private_chat'),
      value: value,
      onTap: _busy ? null : () => _set(!state.enabled),
      trailing: Switch(value: state.enabled, onChanged: _busy ? null : _set),
    );
  }
}
