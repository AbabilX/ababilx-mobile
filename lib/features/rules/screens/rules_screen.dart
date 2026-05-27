import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/glass_card.dart';
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
        title: const Text('Auto Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(rulesProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/rules/new'),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.indigo),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 16),
              OutlineButton(
                label: 'Retry',
                onPressed: () => ref.read(rulesProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
        data: (rules) => rules.isEmpty
            ? EmptyState(
                icon: Icons.schedule_outlined,
                title: 'No rules yet',
                subtitle:
                    'Create a rule to automatically send standup messages to Slack.',
                action: GradientButton(
                  label: 'Create first rule',
                  icon: Icons.add,
                  onPressed: () => context.go('/rules/new'),
                ),
              )
            : RefreshIndicator(
                color: AppColors.indigo,
                backgroundColor: AppColors.surface2,
                onRefresh: () =>
                    ref.read(rulesProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: rules.length,
                  itemBuilder: (_, i) => _RuleCard(
                    rule: rules[i],
                    index: i,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RuleCard extends ConsumerWidget {
  const _RuleCard({required this.rule, required this.index});
  final Rule rule;
  final int index;

  RuleStatus get _status {
    if (!rule.isActive) return RuleStatus.paused;
    if (rule.runMode == 'once') {
      return rule.lastSentAt != null
          ? RuleStatus.sent
          : RuleStatus.scheduled;
    }
    return RuleStatus.running;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RuleStatusBadge(status: _status),
            ],
          ),

          const SizedBox(height: 10),

          // Channel + schedule info
          Row(
            children: [
              const Icon(Icons.tag, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                rule.channelName.isNotEmpty
                    ? rule.channelName
                    : 'No channel',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  rule.runMode == 'once'
                      ? '${rule.targetDate ?? ''} at ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}'
                      : '${AppDateUtils.formatDays(rule.daysOfWeek)} at ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (rule.notificationMinutes != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.notifications_outlined,
                    size: 14, color: AppColors.indigo),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.minutesLabel(rule.notificationMinutes),
                  style: const TextStyle(
                      color: AppColors.indigoLight, fontSize: 12),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Toggle active
              _ActionBtn(
                icon: rule.isActive
                    ? Icons.pause_outlined
                    : Icons.play_arrow_outlined,
                tooltip: rule.isActive ? 'Pause' : 'Resume',
                onTap: () => ref
                    .read(rulesProvider.notifier)
                    .toggleRule(rule.id, !rule.isActive),
              ),
              // Send now
              _ActionBtn(
                icon: Icons.send_outlined,
                tooltip: 'Send now',
                onTap: () async {
                  await ref.read(rulesProvider.notifier).triggerRule(rule.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent!')),
                    );
                  }
                },
              ),
              // History
              _ActionBtn(
                icon: Icons.history_outlined,
                tooltip: 'History',
                onTap: () => context.go('/rules/${rule.id}/history'),
              ),
              // Edit
              _ActionBtn(
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
                onTap: () => context.go('/rules/${rule.id}/edit'),
              ),
              // Delete
              _ActionBtn(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: AppColors.red,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 60).ms).slideY(begin: 0.05, end: 0);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Delete Rule',
            style: TextStyle(color: AppColors.text)),
        content: Text(
          'Delete "${rule.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(rulesProvider.notifier).deleteRule(rule.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: color),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
