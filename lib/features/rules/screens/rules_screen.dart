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

    return GestureDetector(
      onTap: () => context.go('/rules/${rule.id}/history'),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
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

                // Note quick-tap icon
                GestureDetector(
                  onTap: () => _showNoteSheet(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rule.note.isNotEmpty
                          ? const Color(0xFF381E72)
                          : const Color(0xFF25232A),
                      border: Border.all(
                        color: rule.note.isNotEmpty
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : theme.colorScheme.outline,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: rule.note.isNotEmpty
                          ? const Color(0xFFE8DEF8)
                          : const Color(0xFFCAC4D0),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Power toggle
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
                          ? theme.colorScheme.primary
                          : const Color(0xFF25232A),
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
                          ? theme.colorScheme.onPrimary
                          : const Color(0xFFCAC4D0),
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

          const SizedBox(height: 18),
        ],
      ),
    ));
  }

  void _showNoteSheet(BuildContext context) {
    final ctrl = TextEditingController(text: widget.rule.note);
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF211F26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF49454F),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.psychology_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 10),
              const Text('Quick Note for AI',
                  style: TextStyle(color: Color(0xFFE6E1E5), fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Extra context for the next send — meetings, blockers, decisions.',
              style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Had planning meeting, blocked on auth service…',
                prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  await ref.read(rulesProvider.notifier).updateNote(widget.rule.id, ctrl.text);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Note', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
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

