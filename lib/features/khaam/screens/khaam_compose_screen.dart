import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_send.dart';
import '../providers/jpack_compose_provider.dart';
import '../widgets/jpack_compose_parts.dart';
import '../widgets/jpack_bottom_bar.dart';
import '../widgets/jpack_compose_dock.dart';
import '../widgets/jpack_dock_row.dart';
import 'jpack_cover_gallery_screen.dart';

/// Message and cover, then send. Pops `true` once the JPack is in the
/// conversation.
///
/// All screen state lives in [jpackComposeProvider]. The only `State` here
/// holds the message controller, which `ref.listen` keeps in step with the
/// notifier when the dice, the language switch or a cover changes the text
/// from outside the field.
class JPackComposeScreen extends ConsumerStatefulWidget {
  const JPackComposeScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    required this.initialCover,
  });

  final String conversationId;
  final String recipientName;
  final JPackCover initialCover;

  @override
  ConsumerState<JPackComposeScreen> createState() => _JPackComposeScreenState();
}

class _JPackComposeScreenState extends ConsumerState<JPackComposeScreen> {
  late final TextEditingController _messageCtrl = TextEditingController(
    text: ref.read(jpackComposeProvider(widget.initialCover)).message,
  );

  JPackComposeNotifier get _notifier =>
      ref.read(jpackComposeProvider(widget.initialCover).notifier);

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover(JPackCover current) async {
    final cover = await Navigator.of(context).push<JPackCover>(
      MaterialPageRoute(
        builder: (_) => JPackCoverGalleryScreen(
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
    final draft = ref.read(jpackComposeProvider(widget.initialCover));
    final payload = JPackPayload(
      id: draft.jpackId,
      coverId: draft.cover.id,
      message: draft.outgoingMessage,
      lang: draft.lang,
    );
    _notifier.setBusy(true);
    final delivered = await sendJPack(
      ref,
      conversationId: widget.conversationId,
      payload: payload,
    );
    if (!mounted) return;
    if (!delivered) {
      showAppToast(
        context,
        AppTranslations.translate(context, ref, 'jpack_send_failed'),
        isError: true,
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final provider = jpackComposeProvider(widget.initialCover);
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
                title: Text(t('jpack_send_title')),
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
                    JPackSettingRow(
                      child: TextField(
                        controller: _messageCtrl,
                        maxLength: 80,
                        minLines: 1,
                        maxLines: 3,
                        onChanged: _notifier.typeMessage,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          hintText: t('jpack_message_hint'),
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
                    JPackCardPreview(
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
            child: JPackBottomBar(
              action: JPackSendPill(
                icon: HugeIcons.strokeRoundedSent,
                color: cover.flap,
                label: t('jpack_send_title'),
                busy: draft.busy,
                onTap: _send,
              ),
              child: JPackComposeDock(
                langLabel: draft.lang == 'bn' ? 'বাংলা' : 'English',
                captionsLabel: t('jpack_tab_captions'),
                coverLabel: t('jpack_cover'),
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
