import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/khaam_covers.dart';
import '../data/khaam_payload.dart';
import '../data/khaam_send.dart';
import '../providers/khaam_compose_provider.dart';
import '../widgets/khaam_compose_parts.dart';
import '../widgets/khaam_bottom_bar.dart';
import '../widgets/khaam_compose_dock.dart';
import '../widgets/khaam_dock_row.dart';
import 'khaam_cover_gallery_screen.dart';

/// Message and cover, then send. Pops `true` once the Khaam is in the
/// conversation.
///
/// All screen state lives in [khaamComposeProvider]. The only `State` here
/// holds the message controller, which `ref.listen` keeps in step with the
/// notifier when the dice, the language switch or a cover changes the text
/// from outside the field.
class KhaamComposeScreen extends ConsumerStatefulWidget {
  const KhaamComposeScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    required this.initialCover,
  });

  final String conversationId;
  final String recipientName;
  final KhaamCover initialCover;

  @override
  ConsumerState<KhaamComposeScreen> createState() => _KhaamComposeScreenState();
}

class _KhaamComposeScreenState extends ConsumerState<KhaamComposeScreen> {
  late final TextEditingController _messageCtrl = TextEditingController(
    text: ref.read(khaamComposeProvider(widget.initialCover)).message,
  );

  KhaamComposeNotifier get _notifier =>
      ref.read(khaamComposeProvider(widget.initialCover).notifier);

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover(KhaamCover current) async {
    final cover = await Navigator.of(context).push<KhaamCover>(
      MaterialPageRoute(
        builder: (_) => KhaamCoverGalleryScreen(
          conversationId: widget.conversationId,
          recipientName: widget.recipientName,
          selectedId: current.id,
          picking: true,
        ),
      ),
    );
    if (cover == null || !mounted) return;
    _notifier.setCover(cover);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final draft = ref.read(khaamComposeProvider(widget.initialCover));
    final payload = KhaamPayload(
      id: draft.khaamId,
      coverId: draft.cover.id,
      message: draft.outgoingMessage,
      lang: draft.lang,
    );
    _notifier.setBusy(true);
    final delivered = await sendKhaam(
      ref,
      conversationId: widget.conversationId,
      payload: payload,
    );
    if (!mounted) return;
    if (!delivered) {
      showAppToast(
        context,
        AppTranslations.translate(context, ref, 'khaam_send_failed'),
        isError: true,
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final provider = khaamComposeProvider(widget.initialCover);
    final theme = Theme.of(context);
    final draft = ref.watch(provider);
    final cover = draft.cover;

    ref.listen(provider.select((s) => s.message), (_, next) {
      if (_messageCtrl.text == next) return;
      _messageCtrl.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(t('khaam_send_title')),
                centerTitle: true,
                floating: true,
                snap: true,
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  ShellPillMetrics.contentBottom(context),
                ),
                sliver: SliverList.list(
                  children: [
                    KhaamSettingRow(
                      child: TextField(
                        controller: _messageCtrl,
                        maxLength: 80,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: _notifier.typeMessage,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          hintText: t('khaam_message_hint'),
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    KhaamCardPreview(
                      cover: cover,
                      message: draft.outgoingMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: KhaamBottomBar(
              action: KhaamSendPill(
                icon: HugeIcons.strokeRoundedSent,
                color: cover.flap,
                label: t('khaam_send_title'),
                busy: draft.busy,
                onTap: _send,
              ),
              child: KhaamComposeDock(
                langLabel: draft.lang == 'bn' ? 'বাংলা' : 'English',
                captionsLabel: t('khaam_tab_captions'),
                coverLabel: t('khaam_cover'),
                onLang: () =>
                    _notifier.setLang(draft.lang == 'bn' ? 'en' : 'bn'),
                onCaptions: _notifier.shuffle,
                onCover: () => _pickCover(cover),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
