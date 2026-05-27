import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../providers/rules_provider.dart';

/// The pre-send review screen.
/// Opened by:
/// - Notification tap (fromNotification = true): shows countdown + auto-send context
/// - Manual tap from rule card (fromNotification = false): simple preview mode
class MessagePreviewScreen extends ConsumerStatefulWidget {
  const MessagePreviewScreen({
    super.key,
    required this.ruleId,
    this.fromNotification = false,
  });

  final String ruleId;
  final bool fromNotification;

  @override
  ConsumerState<MessagePreviewScreen> createState() =>
      _MessagePreviewScreenState();
}

class _MessagePreviewScreenState extends ConsumerState<MessagePreviewScreen> {
  final _controller = TextEditingController();
  bool _edited = false;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    // Auto-fetch AI preview on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rulePreviewProvider(widget.ruleId).notifier).generate(widget.ruleId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendNow() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(rulePreviewProvider(widget.ruleId).notifier)
          .triggerWithMessage(widget.ruleId, _controller.text.trim());
      setState(() {
        _sending = false;
        _sent = true;
      });
      // Invalidate history so it refreshes next time
      ref.invalidate(ruleMessagesProvider(widget.ruleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent to Slack ✓')),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _saveOverride() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    await ref
        .read(rulePreviewProvider(widget.ruleId).notifier)
        .saveOverride(widget.ruleId, content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved! Will send your version automatically.'),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(rulePreviewProvider(widget.ruleId));

    // Populate controller when preview loads (first time only)
    ref.listen(rulePreviewProvider(widget.ruleId), (_, next) {
      if (next.hasValue && next.value != null && _controller.text.isEmpty) {
        _controller.text = next.value!;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.fromNotification
            ? 'Review Before Send'
            : 'Message Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Regenerate button
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Regenerate AI message',
            onPressed: () {
              _controller.clear();
              _edited = false;
              ref
                  .read(rulePreviewProvider(widget.ruleId).notifier)
                  .generate(widget.ruleId);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner for notification context
              if (widget.fromNotification) ...[
                _NotificationBanner(ruleId: widget.ruleId),
                const SizedBox(height: 16),
              ],

              // Preview card
              Expanded(
                child: previewAsync.when(
                  loading: () => GlassCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(color: AppColors.indigo),
                        SizedBox(height: 12),
                        Text(
                          'Generating AI message…',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => GlassCard(
                    child: Center(
                      child: Text(
                        'Could not generate preview:\n$e',
                        style:
                            const TextStyle(color: AppColors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (_) => GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 16, color: AppColors.indigoLight),
                              const SizedBox(width: 6),
                              const Text(
                                'AI-Generated Message',
                                style: TextStyle(
                                  color: AppColors.indigoLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (_edited)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Edited',
                                    style: TextStyle(
                                        color: AppColors.amber, fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: AppColors.border),
                        // Editable text area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 14,
                                height: 1.6,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Edit the message here…',
                                hintStyle:
                                    TextStyle(color: AppColors.textMuted),
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) {
                                if (!_edited) setState(() => _edited = true);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              if (!_sent) ...[
                GradientButton(
                  label: 'Send Now',
                  icon: Icons.send,
                  isLoading: _sending,
                  onPressed: previewAsync.hasValue ? _sendNow : null,
                ),
                const SizedBox(height: 10),
                if (widget.fromNotification && _edited) ...[
                  GradientButton(
                    label: 'Save & Let Auto-Send',
                    icon: Icons.save_outlined,
                    onPressed: _saveOverride,
                  ),
                  const SizedBox(height: 10),
                ],
                OutlineButton(
                  label: widget.fromNotification
                      ? 'Ignore — Auto-send as-is'
                      : 'Close',
                  onPressed: () => context.pop(),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Sent to Slack!',
                          style: TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a countdown timer when opened from a notification.
class _NotificationBanner extends ConsumerStatefulWidget {
  const _NotificationBanner({required this.ruleId});
  final String ruleId;

  @override
  ConsumerState<_NotificationBanner> createState() =>
      _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<_NotificationBanner> {
  // We show a generic countdown since we don't know exact time from the client.
  // The backend sends X minutes before; we approximate remaining time.
  int _remainingSeconds = 600; // 10 min default display
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.indigoGlow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active,
              size: 18, color: AppColors.indigoLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-sends in $_countdown unless you edit or send now',
              style: const TextStyle(
                  color: AppColors.indigoLight, fontSize: 13),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }
}
