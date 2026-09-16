import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/jpack_covers.dart';
import '../data/jpack_money.dart';
import '../data/jpack_payload.dart';
import '../data/jpack_send.dart';
import '../data/wallet_repository.dart';
import '../providers/jpack_compose_provider.dart';
import '../providers/jpack_providers.dart';
import '../widgets/ababil_pay_sheet.dart';
import '../widgets/jpack_balance_chip.dart';
import '../widgets/jpack_cover_art.dart';
import 'jpack_cover_gallery_screen.dart';

/// Amount, message, cover — then Ababil Pay. Pops `true` once the JPack is
/// in the conversation.
///
/// All screen state lives in [jpackComposeProvider]. The only `State` here
/// holds the two text controllers, which `ref.listen` keeps in step with the
/// notifier when the dice, the language switch, a cover or a quick amount
/// changes the text from outside the field.
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
  static const _quickAmounts = [100.0, 500.0, 1000.0];

  final _amountCtrl = TextEditingController();
  late final TextEditingController _messageCtrl = TextEditingController(
    text: ref.read(jpackComposeProvider(widget.initialCover)).message,
  );

  JPackComposeNotifier get _notifier =>
      ref.read(jpackComposeProvider(widget.initialCover).notifier);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  static void _sync(TextEditingController ctrl, String text) {
    if (ctrl.text == text) return;
    ctrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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

  Future<void> _prepare() async {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final amount = ref.read(jpackComposeProvider(widget.initialCover)).amount;
    if (amount == null) {
      showAppToast(context, t('jpack_amount_invalid'), isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final paid = await showAbabilPaySheet(
      context,
      recipientName: widget.recipientName,
      amount: amount,
    );
    if (!paid || !mounted) return;

    final draft = ref.read(jpackComposeProvider(widget.initialCover));
    final payload = JPackPayload(
      id: draft.jpackId,
      coverId: draft.cover.id,
      amount: amount,
      message: draft.outgoingMessage,
      lang: draft.lang,
    );
    _notifier.setBusy(true);
    try {
      final delivered = await sendJPack(
        ref,
        conversationId: widget.conversationId,
        payload: payload,
      );
      if (!mounted) return;
      if (!delivered) {
        showAppToast(context, t('jpack_send_failed'), isError: true);
      }
      Navigator.of(context).pop(true);
    } on InsufficientBalance {
      if (!mounted) return;
      showAppToast(context, t('jpack_insufficient'), isError: true);
      _notifier.setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final provider = jpackComposeProvider(widget.initialCover);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final draft = ref.watch(provider);
    final cover = draft.cover;
    final balance = ref.watch(walletBalanceProvider).valueOrNull ?? 0;
    final amount = draft.amount;
    final error = switch (draft.problem(balance)) {
      JPackAmountProblem.overMax => t(
        'jpack_amount_max',
      ).replaceAll('{max}', formatTaka(jpackMaxAmount)),
      JPackAmountProblem.overBalance => t('jpack_amount_too_high'),
      null => null,
    };
    final canSend = amount != null && error == null && !draft.busy;

    ref.listen(
      provider.select((s) => s.message),
      (_, next) => _sync(_messageCtrl, next),
    );
    ref.listen(
      provider.select((s) => s.amountText),
      (_, next) => _sync(_amountCtrl, next),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('jpack_send_title')),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: JPackBalanceChip(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Row(
              child: Row(
                children: [
                  Text(t('jpack_amount'), style: theme.textTheme.titleMedium),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      onChanged: _notifier.setAmountText,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,6}(\.\d{0,2})?'),
                        ),
                      ],
                      style: theme.textTheme.titleLarge,
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        prefixText: '৳ ',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final q in _quickAmounts)
                    ChoiceChip(
                      label: Text(formatTaka(q)),
                      selected: amount == q,
                      onSelected: (_) =>
                          _notifier.setAmountText(q.toStringAsFixed(0)),
                    ),
                  if (error != null)
                    Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Row(
              child: Row(
                children: [
                  Expanded(
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
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LangToggle(lang: draft.lang, onChanged: _notifier.setLang),
                  IconButton(
                    tooltip: t('jpack_shuffle'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _notifier.shuffle();
                    },
                    icon: const Icon(Icons.casino_rounded),
                    color: cover.flap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Row(
              onTap: () => _pickCover(cover),
              child: Row(
                children: [
                  Text(t('jpack_cover'), style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    t(cover.nameKey),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  JPackCoverArt(cover: cover, width: 26, radius: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Hero(
                tag: 'jpack-cover-${cover.id}',
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: JPackCoverArt(
                    key: ValueKey(cover.id),
                    cover: cover,
                    width: 170,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 22, 14, 0),
                      child: Text(
                        draft.outgoingMessage,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cover.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black38),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                formatTaka(amount ?? 0, fixed: true),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 240,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cover.flap,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canSend ? _prepare : null,
                  child: draft.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          t('jpack_prepare'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AbabilPayMark(size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t('jpack_footer'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One rounded setting row, like the reference's Amount / message / Cover.
class _Row extends StatelessWidget {
  const _Row({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ),
      ),
    );
  }
}

/// বাং / EN for the ready-made messages. It never touches words the user
/// typed.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget seg(String code, String label) {
      final on = lang == code;
      return GestureDetector(
        onTap: () => onChanged(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: on ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: on ? colors.onPrimary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('bn', 'বাং'), seg('en', 'EN')],
      ),
    );
  }
}
