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

  List<Color> get _statusGradientColors => switch (_status) {
        RuleStatus.running => [const Color(0xFF22C55E), const Color(0xFF4ADE80)],
        RuleStatus.paused => [const Color(0xFF475569), const Color(0xFF64748B)],
        RuleStatus.scheduled => [const Color(0xFF6366F1), const Color(0xFF818CF8)],
        RuleStatus.sent => [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      };

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(32),
        ),
        border: Border.all(
          color: rule.isActive
              ? AppColors.indigo.withOpacity(0.24)
              : AppColors.border,
          width: 1.2,
        ),
        boxShadow: rule.isActive
            ? [
                BoxShadow(
                  color: AppColors.indigo.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30.8),
          topRight: Radius.circular(14.8),
          bottomLeft: Radius.circular(14.8),
          bottomRight: Radius.circular(30.8),
        ),
        child: Stack(
          children: [
            // Left dynamic gradient accent strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _statusGradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Main Content Column
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top section ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Pulsing Status Icon squircle badge
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _statusColor.withOpacity(0.24),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: _status == RuleStatus.running
                                ? _PulsingIcon(
                                    icon: _statusIcon,
                                    color: _statusColor,
                                  )
                                : Icon(_statusIcon, color: _statusColor, size: 22),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title Name + Status & slack badges
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
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
                              // Meta tags row: Slack channel + threaded badge
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Slack tag capsule
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface3,
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: AppColors.border, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.tag_rounded, size: 12, color: AppColors.indigoLight),
                                        const SizedBox(width: 4),
                                        Text(
                                          rule.channelName.isNotEmpty
                                              ? rule.channelName
                                              : 'No channel',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Threaded badge capsule
                                  if (rule.threadEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(
                                          color: AppColors.green.withOpacity(0.15),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.forum_rounded, size: 11, color: AppColors.green),
                                          SizedBox(width: 4),
                                          Text(
                                            'Threaded',
                                            style: TextStyle(
                                              color: AppColors.green,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
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

                        // Glowing floating circular toggle button (Image #16 signature style)
                        GestureDetector(
                          onTap: () => ref
                              .read(rulesProvider.notifier)
                              .toggleRule(rule.id, !rule.isActive),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rule.isActive
                                  ? AppColors.indigo
                                  : AppColors.surface3,
                              boxShadow: rule.isActive
                                  ? [
                                      BoxShadow(
                                        color: AppColors.indigo.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                              border: Border.all(
                                color: rule.isActive
                                    ? AppColors.indigoLight.withOpacity(0.5)
                                    : AppColors.border,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.power_settings_new_rounded,
                              color: rule.isActive ? Colors.white : AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Connected Git Repositories Row (if any)
                  if (rule.repoTargets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CONNECTED REPOSITORIES',
                            style: TextStyle(
                              color: AppColors.textMuted,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.indigo.withOpacity(0.12),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.commit_rounded,
                                      size: 12,
                                      color: AppColors.indigoLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${repo.repoFullName.split('/').last}:${repo.branch}',
                                      style: const TextStyle(
                                        color: AppColors.indigoLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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

                  // ── Schedule info glass panel ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.indigo.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: AppColors.indigoLight,
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
                                    color: AppColors.textMuted,
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
                                    color: AppColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (rule.notificationMinutes != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.amber.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notifications_active_rounded,
                                      size: 12, color: AppColors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${rule.notificationMinutes}m prior',
                                    style: const TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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

                  // ── Action bar (Chunky M3 Quick Settings Tiles) ──────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Row(
                      children: [
                        // Trigger Now Tile
                        _TonalIconBtn(
                          icon: Icons.bolt_rounded,
                          tooltip: 'Trigger Now',
                          activeColor: AppColors.indigoLight,
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
                        // View History Tile
                        _TonalIconBtn(
                          icon: Icons.history_rounded,
                          tooltip: 'View History',
                          activeColor: AppColors.textMuted,
                          onTap: () => context.go('/rules/${rule.id}/history'),
                        ),
                        const Spacer(),
                        // Configure/Edit Tile
                        _TonalIconBtn(
                          icon: Icons.tune_rounded,
                          tooltip: 'Configure Rule',
                          activeColor: AppColors.indigoLight,
                          onTap: () => context.go('/rules/${rule.id}/edit'),
                        ),
                        const SizedBox(width: 8),
                        // Delete Tile
                        _TonalIconBtn(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Delete Rule',
                          activeColor: AppColors.red,
                          onTap: () => _confirmDelete(context, ref),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}

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
        color: activeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: activeColor.withOpacity(0.12),
                width: 1,
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
                : Icon(icon, size: 22, color: activeColor),
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

