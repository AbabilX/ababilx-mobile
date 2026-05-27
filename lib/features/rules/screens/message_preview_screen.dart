import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
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
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Message sent to Slack!'),
              ],
            ),
            backgroundColor: AppColors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.red),
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
          content: Row(
            children: [
              Icon(Icons.save_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Saved! Will send your version automatically.'),
            ],
          ),
          backgroundColor: AppColors.indigo,
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
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.fromNotification ? 'Review Standup' : 'Message Preview',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Regenerate button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface2,
              foregroundColor: AppColors.textMuted,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Regenerate AI message',
            onPressed: () {
              _controller.clear();
              _edited = false;
              ref
                  .read(rulePreviewProvider(widget.ruleId).notifier)
                  .generate(widget.ruleId);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Info banner for notification context ─────────────────────
              if (widget.fromNotification) ...[
                _NotificationBanner(ruleId: widget.ruleId),
                const SizedBox(height: 16),
              ],

              // ── Preview Workspace (Glass Deck) ───────────────────────────
              Expanded(
                child: previewAsync.when(
                  loading: () => GlassCard(
                    borderRadius: 24,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.surface.withOpacity(0.3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 2.5),
                        SizedBox(height: 16),
                        Text(
                          'Generating AI message…',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => GlassCard(
                    borderRadius: 24,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.surface.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'Could not generate preview:\n$e',
                            style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (_) => GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 24,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.surface.withOpacity(0.3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  size: 16, color: AppColors.indigoLight),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Draft Workspace',
                                style: TextStyle(
                                  color: AppColors.indigoLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const Spacer(),
                              if (_edited)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.amber.withOpacity(0.2), width: 0.8),
                                  ),
                                  child: const Text(
                                    'Edited',
                                    style: TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        // Editable text area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'Edit draft here…',
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

              // ── Action Buttons ───────────────────────────────────────────
              if (!_sent) ...[
                // Send Now primary button
                GradientButton(
                  label: 'Send Standup Now',
                  icon: Icons.send_rounded,
                  isLoading: _sending,
                  onPressed: previewAsync.hasValue ? _sendNow : null,
                ),
                const SizedBox(height: 10),

                // Save override (once edited in notification mode)
                if (widget.fromNotification && _edited) ...[
                  Material(
                    color: AppColors.indigo.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      onTap: _saveOverride,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.indigo.withOpacity(0.2), width: 1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 18, color: AppColors.indigoLight),
                            SizedBox(width: 8),
                            Text(
                              'Save & Auto-Send Later',
                              style: TextStyle(
                                color: AppColors.indigoLight,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Close/Ignore button
                OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.border),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    widget.fromNotification ? 'Ignore — Send Auto-Draft' : 'Close Workspace',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ] else ...[
                // Sent successfully banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.green.withOpacity(0.2),
                      width: 0.8,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sent to Slack successfully!',
                        style: TextStyle(
                          color: AppColors.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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
        color: AppColors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.indigo.withOpacity(0.24), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              size: 16, color: AppColors.indigoLight)
              .animate(onPlay: (c) => c.repeat())
              .shake(duration: 800.ms, hz: 4),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-sends in $_countdown unless you edit or send now',
              style: const TextStyle(
                  color: AppColors.indigoLight, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
