import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/rule_status_badge.dart';
import '../../../core/localization/app_translations.dart';
import '../data/models/rule.dart';
import '../providers/rules_provider.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppTranslations.translate(context, ref, 'rules_title'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
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
            onPressed: () => ref.read(rulesProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/rules/new'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          AppTranslations.translate(context, ref, 'new_rule'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: rulesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colors.primary,
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
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outline, width: 1.2),
                ),
                child: Icon(Icons.error_outline_rounded,
                    size: 36, color: colors.error),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14),
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
// Rule Card — Authentic Material 3 Style
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

  // Authentic Material 3 Tonal Status Colors
  Color get _statusBg => switch (_status) {
        RuleStatus.running => const Color(0xFF005224), // Tonal green
        RuleStatus.paused => const Color(0xFF2A282F), // Tonal gray
        RuleStatus.scheduled => const Color(0xFF003F7A), // Tonal indigo/blue
        RuleStatus.sent => const Color(0xFF7A4E00), // Tonal amber
      };

  Color get _statusFg => switch (_status) {
        RuleStatus.running => const Color(0xFFC1F8C8),
        RuleStatus.paused => const Color(0xFFCAC4D0),
        RuleStatus.scheduled => const Color(0xFFD4E3FF),
        RuleStatus.sent => const Color(0xFFFFDF9E),
      };

  IconData get _statusIcon => switch (_status) {
        RuleStatus.running => Icons.play_arrow_rounded,
        RuleStatus.paused => Icons.pause_rounded,
        RuleStatus.scheduled => Icons.schedule_rounded,
        RuleStatus.sent => Icons.check_rounded,
      };

  String get _statusLabel => switch (_status) {
        RuleStatus.running => AppTranslations.translate(context, ref, 'rule_active'),
        RuleStatus.paused => AppTranslations.translate(context, ref, 'rule_paused'),
        RuleStatus.scheduled => AppTranslations.translate(context, ref, 'rule_active'),
        RuleStatus.sent => AppTranslations.translate(context, ref, 'sent'),
      };

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28), // Authentic M3 Symmetrical Squircle Card
        border: Border.all(
          color: rule.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top section ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Symmetrical Status Icon Squircle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _status == RuleStatus.running
                        ? _PulsingIcon(
                            icon: _statusIcon,
                            color: _statusFg,
                          )
                        : Icon(_statusIcon, color: _statusFg, size: 20),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + channel & status tags
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
                                color: Color(0xFFE6E1E5),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: _statusLabel,
                            bgColor: _statusBg,
                            fgColor: _statusFg,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Meta tags row: Slack channel + threaded badge
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Slack channel solid capsule tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF381E72), // Solid dark purple track
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag_rounded, size: 12, color: Color(0xFFE8DEF8)),
                                const SizedBox(width: 4),
                                Text(
                                  rule.channelName.isNotEmpty
                                      ? rule.channelName
                                      : 'No channel',
                                  style: const TextStyle(
                                    color: Color(0xFFE8DEF8), // Solid light purple text
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Threaded solid capsule tag
                          if (rule.threadEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF005224),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.forum_rounded, size: 11, color: Color(0xFFC1F8C8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Threaded',
                                    style: TextStyle(
                                      color: Color(0xFFC1F8C8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Signature Circular Active Toggle Button
                GestureDetector(
                  onTap: () => ref
                      .read(rulesProvider.notifier)
                      .toggleRule(rule.id, !rule.isActive),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rule.isActive
                          ? theme.colorScheme.primary // Solid purple active
                          : const Color(0xFF25232A), // Solid dark-surface inactive
                      border: Border.all(
                        color: rule.isActive
                            ? Colors.transparent
                            : theme.colorScheme.outline,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: rule.isActive
                          ? theme.colorScheme.onPrimary // Dark purple icon
                          : const Color(0xFFCAC4D0), // Muted icon
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Connected Git Repositories Row (if any)
          if (rule.repoTargets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONNECTED REPOSITORIES',
                    style: TextStyle(
                      color: Color(0xFFCAC4D0),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: rule.repoTargets.map((repo) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A282F),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.commit_rounded,
                              size: 12,
                              color: Color(0xFFCAC4D0),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${repo.repoFullName.split('/').last}:${repo.branch}',
                              style: const TextStyle(
                                color: Color(0xFFCAC4D0),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // ── Schedule info solid card ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF25232A), // Solid dark surface container
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF381E72),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Color(0xFFE8DEF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.runMode == 'once' ? 'One-time Schedule' : 'Recurring Schedule',
                          style: const TextStyle(
                            color: Color(0xFFCAC4D0),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rule.runMode == 'once'
                              ? '${rule.targetDate ?? ''} at ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}'
                              : '${AppDateUtils.formatDays(rule.daysOfWeek)} · ${AppDateUtils.formatSendTime(rule.sendTime, rule.timezone)}',
                          style: const TextStyle(
                            color: Color(0xFFE6E1E5),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (rule.notificationMinutes != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A4E00),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded,
                              size: 12, color: Color(0xFFFFDF9E)),
                          const SizedBox(width: 4),
                          Text(
                            '${rule.notificationMinutes}m prior',
                            style: const TextStyle(
                              color: Color(0xFFFFDF9E),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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

          // ── Action bar (Chunky M3 Quick Settings Tiles) ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              children: [
                // Trigger Now Tile (Primary Solid color-blocked highlight)
                _TonalIconBtn(
                  icon: Icons.bolt_rounded,
                  tooltip: 'Trigger Now',
                  activeColor: const Color(0xFF21005D), // Dark purple icon
                  backgroundColor: const Color(0xFFE8DEF8), // High-contrast solid light purple
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
                const SizedBox(width: 8),
                // View History Tile (Solid surface container style)
                _TonalIconBtn(
                  icon: Icons.history_rounded,
                  tooltip: 'View History',
                  activeColor: const Color(0xFFCAC4D0),
                  backgroundColor: const Color(0xFF25232A),
                  onTap: () => context.go('/rules/${rule.id}/history'),
                ),
                const Spacer(),
                // Configure/Edit Tile
                _TonalIconBtn(
                  icon: Icons.tune_rounded,
                  tooltip: 'Configure Rule',
                  activeColor: const Color(0xFFCAC4D0),
                  backgroundColor: const Color(0xFF25232A),
                  onTap: () => context.go('/rules/${rule.id}/edit'),
                ),
                const SizedBox(width: 8),
                // Delete Tile (Tonal red color block style)
                _TonalIconBtn(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete Rule',
                  activeColor: const Color(0xFFF2B8B5),
                  backgroundColor: const Color(0xFF601410),
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFF211F26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFF35343B)),
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
                  color: const Color(0xFF601410),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFF2B8B5), size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Rule',
                style: TextStyle(
                  color: Color(0xFFE6E1E5),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Delete "${widget.rule.name}"?\nThis cannot be undone.',
                style: const TextStyle(
                    color: Color(0xFFCAC4D0), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCAC4D0),
                        side: const BorderSide(color: Color(0xFF35343B)),
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
                        Navigator.pop(dialogCtx);
                        ref
                            .read(rulesProvider.notifier)
                            .deleteRule(widget.rule.id);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF601410),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.bgColor, required this.fgColor});
  final String label;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
    required this.activeColor,
    required this.backgroundColor,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color activeColor;
  final Color backgroundColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
                width: 0.8,
              ),
            ),
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                color: const Color(0xFF381E72),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.schedule_send_rounded,
                size: 40,
                color: Color(0xFFE8DEF8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppTranslations.translate(context, ref, 'rules_title'),
              style: const TextStyle(
                color: Color(0xFFE6E1E5),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.translate(context, ref, 'no_rules_desc'),
              style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: AppTranslations.translate(context, ref, 'create_first_rule'),
              icon: Icons.add_rounded,
              onPressed: onCreateTap,
            ),
          ],
        ),
      ),
    );
  }
}

