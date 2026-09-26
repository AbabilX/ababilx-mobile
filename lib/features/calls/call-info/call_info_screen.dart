import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_translations.dart';
import '../calls-list/call_redial.dart';
import '../data/models/call_log_entry.dart';
import '../calls-list/calls_list_chrome.dart';
import '../group/providers/group_call_provider.dart';
import '../providers/call_log_provider.dart';
import '../providers/voice_call_provider.dart';
import 'call_info_format.dart';
import 'call_info_header.dart';
import 'call_info_path.dart';
import 'call_info_row.dart';

/// WhatsApp's Call info: every call with one contact on one day, opened from
/// that contact's stacked row in the call log. Reads the log already loaded,
/// and loads it itself on a cold open.
class CallInfoScreen extends ConsumerStatefulWidget {
  const CallInfoScreen({
    super.key,
    required this.conversationId,
    required this.day,
  });

  final String conversationId;
  final DateTime day;

  @override
  ConsumerState<CallInfoScreen> createState() => _CallInfoScreenState();
}

class _CallInfoScreenState extends ConsumerState<CallInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final log = ref.read(callLogProvider);
      if (log.calls.isEmpty && !log.loading) {
        ref.read(callLogProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(callLogProvider);
    final lang = ref.watch(appLanguageProvider);
    final callBusy =
        ref.watch(voiceCallProvider.select((s) => s.active)) ||
        ref.watch(groupCallProvider.select((s) => s.active));
    String t(String key) => AppTranslations.of(lang, key);
    final calls = callsOnDay(
      log.calls,
      conversationId: widget.conversationId,
      day: widget.day,
    );

    return Scaffold(
      appBar: AppBar(title: Text(t('call_info_title'))),
      body: calls.isEmpty
          ? Center(
              child: log.loading
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : Text(t('call_info_empty')),
            )
          : ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              children: [
                _header(calls.last, callBusy, t),
                const Divider(height: 1),
                CallSectionHeader(title: callInfoDayHeading(widget.day)),
                for (final call in calls) CallInfoRow(entry: call, lang: lang),
              ],
            ),
    );
  }

  /// The newest call names the contact, as it does on the stacked row.
  Widget _header(
    CallLogEntry newest,
    bool callBusy,
    String Function(String) t,
  ) {
    final id = widget.conversationId;
    return CallInfoHeader(
      name: newest.title.isEmpty ? t('calls_unknown') : newest.title,
      avatarUrl: newest.avatarUrl,
      isGroup: newest.isGroup,
      messageLabel: t('call_info_message'),
      talkLabel: t('call_info_talk'),
      onMessage: () => context.push('/messages/$id'),
      onTalk: callBusy
          ? null
          : () => redialCall(context, ref, id, isGroup: newest.isGroup),
    );
  }
}
