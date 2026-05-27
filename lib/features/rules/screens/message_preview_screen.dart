import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final colors = Theme.of(context).colorScheme;
    setState(() => _sending = true);
    try {
      await ref
          .read(rulePreviewProvider(widget.ruleId).notifier)
          .triggerWithMessage(widget.ruleId, _controller.text.trim());
      setState(() {
        _sending = false;
        _sent = true;
      });
      ref.invalidate(ruleMessagesProvider(widget.ruleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Message sent to Slack!'),
              ],
            ),
            backgroundColor: colors.primary,
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.pop();
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: colors.error),
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
      final colors = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.save_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Saved! Will send your version automatically.'),
            ],
          ),
          backgroundColor: colors.primary,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(rulePreviewProvider(widget.ruleId));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    ref.listen(rulePreviewProvider(widget.ruleId), (_, next) {
      if (next.hasValue && next.value != null && _controller.text.isEmpty) {
        _controller.text = next.value!;
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.fromNotification ? 'Review Standup' : 'Message Preview',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceContainerLow,
              foregroundColor: colors.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fromNotification) ...[
                _NotificationBanner(ruleId: widget.ruleId),
                const SizedBox(height: 16),
              ],

              // ── Preview Workspace (Symmetrical M3 Container Sheet) ─────────
              Expanded(
                child: previewAsync.when(
                  loading: () => Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outline, width: 1.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: colors.primary, strokeWidth: 2.5),
                        const SizedBox(height: 16),
                        const Text(
                          'Generating AI message…',
                          style: TextStyle(
                              color: Color(0xFFCAC4D0),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  error: (e, _) => Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outline, width: 1.0),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: colors.error, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'Could not generate preview:\n$e',
                            style: TextStyle(
                                color: colors.error,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (_) => Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.outline, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 18, color: colors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Draft Workspace',
                                style: TextStyle(
                                  color: Color(0xFFE8DEF8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const Spacer(),
                              if (_edited)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF381E72),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                        color: colors.primary, width: 0.8),
                                  ),
                                  child: const Text(
                                    'Edited',
                                    style: TextStyle(
                                      color: Color(0xFFE8DEF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: colors.outline),
                        // Editable text area
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: TextField(
                              controller: _controller,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                                height: 1.6,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: 'Edit draft here…',
                                hintStyle:
                                    TextStyle(color: Color(0xFFCAC4D0)),
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

              const SizedBox(height: 20),

              // ── Action Buttons ───────────────────────────────────────────
              if (!_sent) ...[
                // Send Now primary button: Authentic M3 Stadium Capsule
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: previewAsync.hasValue ? _sendNow : null,
                    icon: _sending
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_rounded, size: 20),
                    label: _sending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: colors.onPrimary,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Send Standup Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Save override (once edited in notification mode): Flat Tonal Purple Capsule
                if (widget.fromNotification && _edited) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveOverride,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text(
                        'Save & Auto-Send Later',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF381E72),
                        foregroundColor: const Color(0xFFE8DEF8),
                        elevation: 0,
                        side: BorderSide(color: colors.outline, width: 1.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Close/Ignore button: Clean Outline Capsule
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      side: BorderSide(color: colors.outline, width: 1.2),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      widget.fromNotification
                          ? 'Ignore — Send Auto-Draft'
                          : 'Close Workspace',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Sent successfully banner: Flat Solid Tonal Green capsule
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF142F1C),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: const Color(0xFF22C55E),
                      width: 1.0,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Sent to Slack successfully!',
                        style: TextStyle(
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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
  int _remainingSeconds = 600;
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF381E72),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD0BCFF), width: 1.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
                  size: 18, color: Color(0xFFE8DEF8))
              .animate(onPlay: (c) => c.repeat())
              .shake(duration: 800.ms, hz: 4),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Auto-sends in $_countdown unless you edit or send now',
              style: const TextStyle(
                  color: Color(0xFFE8DEF8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0, curve: Curves.easeOutCubic);
  }
}
