import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/text/display_name.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/router/shell_bottom_bar/shell_pill_metrics.dart';
import '../data/khaam_covers.dart';
import '../data/khaam_payload.dart';
import '../data/khaam_photo_pick.dart';
import '../data/khaam_send.dart';
import '../providers/khaam_compose_provider.dart';
import '../widgets/khaam_bottom_bar.dart';
import '../widgets/khaam_compose_dock.dart';
import '../widgets/khaam_dock_row.dart';
import '../widgets/khaam_compose_preview.dart';
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

  Future<void> _pickPhoto() async {
    final t = AppTranslations.translate(context, ref, 'khaam_photo_add');
    final photo = await pickKhaamPhoto(context, t);
    if (photo != null && mounted) _notifier.setPhoto(photo);
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final draft = ref.read(khaamComposeProvider(widget.initialCover));
    _notifier.setBusy(true);
    final result = await sendKhaam(
      ref,
      conversationId: widget.conversationId,
      payload: KhaamPayload(
        id: draft.khaamId,
        coverId: draft.cover.id,
        message: draft.outgoingMessage,
        lang: draft.lang,
      ),
      photo: draft.photo,
    );
    if (!mounted) return;
    String t(String key) => AppTranslations.translate(context, ref, key);
    if (result == KhaamSendResult.photoFailed) {
      _notifier.setBusy(false);
      showAppToast(context, t('khaam_photo_failed'), isError: true);
      return;
    }
    if (result == KhaamSendResult.pending) {
      showAppToast(context, t('khaam_send_failed'), isError: true);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final provider = khaamComposeProvider(widget.initialCover);
    final draft = ref.watch(provider);
    final cover = draft.cover;
    // What the receiver reads: this account's own name and photo.
    final profile = ref.watch(profileProvider).valueOrNull;
    final me = safeDisplayName(profile?.name, fallback: 'Ababil X');

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
                    KhaamMessageField(
                      controller: _messageCtrl,
                      hint: t('khaam_message_hint'),
                      onChanged: _notifier.typeMessage,
                    ),
                    const SizedBox(height: 24),
                    KhaamComposePreview(
                      cover: cover,
                      width: math.min(
                        MediaQuery.sizeOf(context).width - 32,
                        340,
                      ),
                      fromLabel: t('khaam_from').replaceAll('{name}', me),
                      senderName: me,
                      senderAvatar: profile?.avatarUrl,
                      message: draft.outgoingMessage,
                      photo: draft.photo,
                      addLabel: t('khaam_photo_add'),
                      changeLabel: t('khaam_photo_change'),
                      onPick: _pickPhoto,
                      onRemove: _notifier.clearPhoto,
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
