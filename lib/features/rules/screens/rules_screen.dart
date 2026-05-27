import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/rule_status_badge.dart';
import '../data/models/rule.dart';
import '../providers/rules_provider.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Auto Messages',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface2,
              foregroundColor: AppColors.textMuted,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(rulesProvider.notifier).refresh(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/rules/new'),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Rule',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: rulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.indigo,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 36, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlineButton(
                label: 'Retry',
                onPressed: () => ref.read(rulesProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
        data: (rules) => rules.isEmpty
            ? _EmptyState(onCreateTap: () => context.go('/rules/new'))
            : RefreshIndicator(
                color: AppColors.indigo,
                backgroundColor: AppColors.surface2,
                onRefresh: () => ref.read(rulesProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: rules.length,
                  itemBuilder: (_, i) => _RuleCard(rule: rules[i], index: i),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rule Card — M3 Expressive style
// ---------------------------------------------------------------------------

class _RuleCard extends ConsumerStatefulWidget {
  const _RuleCard({required this.rule, required this.index});
  final Rule rule;
  final int index;

  @override
  ConsumerState<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends ConsumerState<_RuleCard> {
  bool _sending = false;

  RuleStatus get _status {
    if (!widget.rule.isActive) return RuleStatus.paused;
    if (widget.rule.runMode == 'once') {
      return widget.rule.lastSentAt != null
          ? RuleStatus.sent
          : RuleStatus.scheduled;
    }
    return RuleStatus.running;
  }

  Color get _statusColor => switch (_status) {
        RuleStatus.running => AppColors.green,
        RuleStatus.paused => AppColors.textMuted,
        RuleStatus.scheduled => AppColors.indigo,
        RuleStatus.sent => AppColors.amber,
      };

  IconData get _statusIcon => switch (_status) {
        RuleStatus.running => Icons.play_arrow_rounded,
        RuleStatus.paused => Icons.pause_rounded,
        RuleStatus.scheduled => Icons.schedule_rounded,
        RuleStatus.sent => Icons.check_rounded,
      };

  String get _statusLabel => switch (_status) {
        RuleStatus.running => 'Active',
        RuleStatus.paused => 'Paused',
        RuleStatus.scheduled => 'Scheduled',
        RuleStatus.sent => 'Sent',
      };

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.rule.isActive
              ? AppColors.borderHover
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top section ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Name + status chip
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.name,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: _statusLabel,
                            color: _statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Channel row
                      Row(
                        children: [
                          Icon(Icons.tag_rounded,
                              size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            rule.channelName.isNotEmpty
                                ? rule.channelName
                                : 'No channel',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Schedule info ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      size: 15, color: AppColors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.runMode == 'once'
                          ? '${rule.targetDate ?? ''} at ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}'
                          : '${AppDateUtils.formatDays(rule.daysOfWeek)} · ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (rule.notificationMinutes != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.notifications_rounded,
                        size: 14, color: AppColors.indigoLight),
                    const SizedBox(width: 3),
                    Text(
                      AppDateUtils.minutesLabel(rule.notificationMinutes),
                      style: const TextStyle(
                          color: AppColors.indigoLight, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Action bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                // Active toggle
                _TonalIconBtn(
                  icon: rule.isActive
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: rule.isActive ? 'Pause' : 'Resume',
                  activeColor:
                      rule.isActive ? AppColors.amber : AppColors.green,
                  onTap: () => ref
                      .read(rulesProvider.notifier)
                      .toggleRule(rule.id, !rule.isActive),
                ),
                const SizedBox(width: 6),
                // Send now
                _TonalIconBtn(
                  icon: Icons.send_rounded,
                  tooltip: 'Send now',
                  activeColor: AppColors.indigo,
                  loading: _sending,
                  onTap: () async {
                    setState(() => _sending = true);
                    try {
                      await ref
                          .read(rulesProvider.notifier)
                          .triggerRule(rule.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Message sent!'),
                              ],
                            ),
                            backgroundColor: AppColors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _sending = false);
                    }
                  },
                ),
                const Spacer(),
                // History
                _TonalIconBtn(
                  icon: Icons.history_rounded,
                  tooltip: 'History',
                  onTap: () => context.go('/rules/${rule.id}/history'),
                ),
                const SizedBox(width: 6),
                // Edit
                _TonalIconBtn(
                  icon: Icons.edit_rounded,
                  tooltip: 'Edit',
                  onTap: () => context.go('/rules/${rule.id}/edit'),
                ),
                const SizedBox(width: 6),
                // Delete
                _TonalIconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  activeColor: AppColors.red,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (widget.index * 60).ms, duration: 280.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.red, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Rule',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Delete "${widget.rule.name}"?\nThis cannot be undone.',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref
                            .read(rulesProvider.notifier)
                            .deleteRule(widget.rule.id);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TonalIconBtn extends StatelessWidget {
  const _TonalIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.activeColor = AppColors.textMuted,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color activeColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: activeColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: activeColor,
                      ),
                    ),
                  )
                : Icon(icon, size: 20, color: activeColor),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.schedule_send_rounded,
                size: 40,
                color: AppColors.indigo,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No rules yet',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a rule to automatically send\nstandup messages to Slack.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Create first rule',
              icon: Icons.add_rounded,
              onPressed: onCreateTap,
            ),
          ],
        ),
      ),
    );
  }
}

