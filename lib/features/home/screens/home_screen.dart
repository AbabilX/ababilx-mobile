import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../auto_commit/providers/auto_commit_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../../rules/data/models/rule.dart';
import '../../rules/providers/rules_provider.dart';
import '../data/activity_repository.dart';
import '../providers/activity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, bool> _sending = {};
  final Map<String, bool> _saving = {};
  final PageController _pager = PageController(viewportFraction: 0.88);
  int _page = 0;

  static int _todayAppDay() {
    final d = DateTime.now().weekday;
    return d == 7 ? 0 : d;
  }

  List<Rule> _todayRules(List<Rule> rules) {
    final today = _todayAppDay();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return rules.where((r) {
      if (!r.isActive) return false;
      if (r.runMode == 'once') {
        return r.targetDate != null && r.targetDate!.substring(0, 10) == todayStr;
      }
      return r.daysOfWeek.contains(today);
    }).toList();
  }

  TextEditingController _ctrlFor(Rule rule) =>
      _noteControllers.putIfAbsent(rule.id, () => TextEditingController(text: rule.note));

  @override
  void dispose() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    _pager.dispose();
    super.dispose();
  }

  Future<void> _saveNote(Rule rule) async {
    final text = _noteControllers[rule.id]?.text ?? '';
    if (text == rule.note) return;
    setState(() => _saving[rule.id] = true);
    try {
      await ref.read(rulesProvider.notifier).updateNote(rule.id, text);
    } finally {
      if (mounted) setState(() => _saving[rule.id] = false);
    }
  }

  Future<void> _sendNow(Rule rule) async {
    await _saveNote(rule);
    setState(() => _sending[rule.id] = true);
    try {
      await ref.read(rulesProvider.notifier).triggerRule(rule.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sent to #${rule.channelName}'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending[rule.id] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final rulesAsync = ref.watch(rulesProvider);
    final commitAsync = ref.watch(autoCommitProvider);
    final activityAsync = ref.watch(activityProvider);

    final user = profileAsync.valueOrNull;
    final rules = rulesAsync.valueOrNull ?? [];
    final commitMeta = commitAsync.valueOrNull;
    final activity = activityAsync.valueOrNull ?? ActivityData.empty();
    final todayRules = _todayRules(rules);
    final activeRules = rules.where((r) => r.isActive).toList();
    final activeJobs = commitMeta?.jobs.where((j) => j.isActive).toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Top header bar ─────────────────────────────────────────────
          _TopBar(
            user: user,
            onAvatarTap: () => context.go('/profile'),
          ),

          // ── Main content panel (rounded top, fills rest) ───────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0E0E18),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.read(rulesProvider.notifier).refresh(),
                    ref.read(autoCommitProvider.notifier).refresh(),
                    ref.read(activityProvider.notifier).refresh(),
                    ref.read(profileProvider.notifier).refresh(),
                  ]);
                },
                color: AppColors.indigo,
                backgroundColor: AppColors.surface2,
                displacement: 20,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // "Overview" title
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                        child: Text(
                          'Overview',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                    ),

                    // ── Stat row ─────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Active Rules',
                                value: '${activeRules.length}',
                                subLabel: 'of ${rules.length} total',
                                icon: Icons.bolt_rounded,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatCard(
                                label: 'This Week',
                                value: '${activity.totalThisWeek}',
                                subLabel: '${activity.totalStandups} standups · ${activity.totalCommits} commits',
                                icon: Icons.bar_chart_rounded,
                                color: AppColors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Activity bar chart ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ActivityCard(activity: activity),
                      ),
                    ),

                    // ── Today's standups pager ────────────────────────────
                    if (todayRules.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.today_rounded, size: 14, color: AppColors.indigo),
                              const SizedBox(width: 6),
                              const Text(
                                "Today's Standups",
                                style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              _CountBadge(count: todayRules.length),
                              const Spacer(),
                              if (todayRules.length > 1)
                                Text(
                                  '${_page + 1} / ${todayRules.length}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 252,
                          child: PageView.builder(
                            controller: _pager,
                            itemCount: todayRules.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (_, i) => _StandupCard(
                              rule: todayRules[i],
                              controller: _ctrlFor(todayRules[i]),
                              isSending: _sending[todayRules[i].id] ?? false,
                              isSaving: _saving[todayRules[i].id] ?? false,
                              onSend: () => _sendNow(todayRules[i]),
                              onBlur: () => _saveNote(todayRules[i]),
                              onEdit: () => context.go('/rules/${todayRules[i].id}/edit'),
                            ),
                          ),
                        ),
                      ),
                      if (todayRules.length > 1)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                todayRules.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _page ? 20 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i == _page ? AppColors.indigo : AppColors.border,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],

                    // ── Active rules list ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: AppColors.green),
                            const SizedBox(width: 6),
                            const Text('Active Rules', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                            if (activeRules.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _CountBadge(count: activeRules.length, color: AppColors.green),
                            ],
                            const Spacer(),
                            GestureDetector(
                              onTap: () => context.go('/rules'),
                              child: const Text('See more ›', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _RulesCard(
                          rules: activeRules,
                          onTap: (r) => context.go('/rules/${r.id}/edit'),
                          onCreateTap: () => context.go('/rules/new'),
                        ),
                      ),
                    ),

                    // ── Active commit jobs ────────────────────────────────
                    if (activeJobs.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.commit_rounded, size: 14, color: AppColors.indigo),
                              const SizedBox(width: 6),
                              const Text('Commit Jobs', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              _CountBadge(count: activeJobs.length),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => context.go('/auto-commit'),
                                child: const Text('See more ›', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CommitJobsCard(
                            jobs: activeJobs,
                            onTap: (job) => context.go('/auto-commit/${job.id}/edit'),
                          ),
                        ),
                      ),
                    ],

                    // ── Quick actions ─────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                        child: const Text('Quick Actions', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _QuickActionsGrid(),
                      ),
                    ),

                    // ── Integrations ──────────────────────────────────────
                    if (user != null) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                          child: const Text('Integrations', style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _IntegrationsCard(user: user),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.user, required this.onAvatarTap});
  final AppUser? user;
  final VoidCallback onAvatarTap;

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Row(
          children: [
            // Logo + greeting
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_rounded, color: AppColors.indigoLight, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  user == null ? 'AbabilX' : user!.name.split(' ').first,
                  style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
              ],
            ),
            const Spacer(),
            // Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: ClipOval(
                      child: user != null && user!.avatarUrl.isNotEmpty
                          ? Image.network(user!.avatarUrl, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded, color: AppColors.textMuted, size: 20),
                    ),
                  ),
                  if (user != null && user!.plan != 'free')
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 1.5),
                        ),
                        child: const Icon(Icons.star_rounded, size: 7, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.subLabel, required this.icon, required this.color});
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1),
          ),
          const SizedBox(height: 4),
          Text(subLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Activity bar chart card ───────────────────────────────────────────────────

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.activity});
  final ActivityData activity;

  static const _dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxVal = activity.days.map((d) => d.total).fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal < 1 ? 1 : maxVal;
    final isLoading = ref.watch(activityProvider).isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: "Activity" + period toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activity', style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
              GestureDetector(
                onTap: isLoading
                    ? null
                    : () {
                        final next = activity.isMonthly ? 'weekly' : 'monthly';
                        ref.read(activityProvider.notifier).setPeriod(next);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: activity.isMonthly
                        ? AppColors.indigo.withValues(alpha: 0.15)
                        : AppColors.surface3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activity.isMonthly
                          ? AppColors.indigo.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.indigo),
                        )
                      else
                        Icon(
                          activity.isMonthly ? Icons.calendar_month_rounded : Icons.calendar_view_week_rounded,
                          size: 11,
                          color: activity.isMonthly ? AppColors.indigoLight : AppColors.textMuted,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        activity.isMonthly ? 'Monthly' : 'Weekly',
                        style: TextStyle(
                          color: activity.isMonthly ? AppColors.indigoLight : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 11,
                        color: activity.isMonthly ? AppColors.indigoLight : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Total number
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${activity.totalThisWeek}',
                  style: const TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1),
                ),
                const TextSpan(
                  text: ' actions',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${activity.totalStandups} standups  ·  ${activity.totalCommits} commits',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),

          const SizedBox(height: 14),

          // Chart
          activity.isMonthly
              ? _MonthlyChart(activity: activity, effectiveMax: effectiveMax)
              : _WeeklyChart(activity: activity, effectiveMax: effectiveMax, dowLabels: _dowLabels),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.activity, required this.effectiveMax, required this.dowLabels});
  final ActivityData activity;
  final int effectiveMax;
  final List<String> dowLabels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: activity.days.map((d) {
          final isToday = d.day == activity.today;
          final barH = d.total == 0 ? 8.0 : (d.total / effectiveMax * 56).clamp(10.0, 56.0);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    width: 24,
                    height: barH,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.indigo
                          : d.total == 0
                              ? AppColors.surface3
                              : AppColors.indigo.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dowLabels[d.day],
                style: TextStyle(
                  color: isToday ? AppColors.indigoLight : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.activity, required this.effectiveMax});
  final ActivityData activity;
  final int effectiveMax;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: activity.days.map((d) {
            final isToday = d.day == activity.today;
            final barH = d.total == 0 ? 6.0 : (d.total / effectiveMax * 56).clamp(8.0, 56.0);
            // Label every 5th day and today
            final showLabel = d.day % 5 == 1 || isToday;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        width: 14,
                        height: barH,
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.indigo
                              : d.total == 0
                                  ? AppColors.surface3
                                  : AppColors.indigo.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 14,
                    child: Text(
                      showLabel ? '${d.day}' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isToday ? AppColors.indigoLight : AppColors.textMuted,
                        fontSize: 8,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Standup card (pager item) ─────────────────────────────────────────────────

class _StandupCard extends StatelessWidget {
  const _StandupCard({
    required this.rule,
    required this.controller,
    required this.isSending,
    required this.isSaving,
    required this.onSend,
    required this.onBlur,
    required this.onEdit,
  });
  final Rule rule;
  final TextEditingController controller;
  final bool isSending;
  final bool isSaving;
  final VoidCallback onSend;
  final VoidCallback onBlur;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rule.name, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '#${rule.channelName.isNotEmpty ? rule.channelName : rule.channelId}  ·  ${rule.sendTime}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Focus(
                onFocusChange: (f) { if (!f) onBlur(); },
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Add AI context for today\'s standup…',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.surface.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.indigo, width: 1.5)),
                    suffixIcon: isSaving
                        ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.indigo)))
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GradientButton(label: 'Send Now', icon: Icons.send_rounded, isLoading: isSending, width: double.infinity, height: 40, onPressed: isSending ? null : onSend),
          ],
        ),
      ),
    );
  }
}

// ── Rules card ───────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.rules, required this.onTap, required this.onCreateTap});
  final List<Rule> rules;
  final ValueChanged<Rule> onTap;
  final VoidCallback onCreateTap;

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.bolt_outlined, color: AppColors.textMuted, size: 16),
            const SizedBox(width: 10),
            const Expanded(child: Text('No active rules', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
            GestureDetector(
              onTap: onCreateTap,
              child: const Text('Create ›', style: TextStyle(color: AppColors.indigoLight, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: rules.take(4).toList().asMap().entries.map((e) {
          final isLast = e.key == (rules.take(4).length - 1);
          final rule = e.value;
          return InkWell(
            onTap: () => onTap(rule),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(18))
                : BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rule.name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '#${rule.channelName.isNotEmpty ? rule.channelName : rule.channelId}  ·  ${rule.sendTime}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    rule.lastSentAt != null ? _timeAgo(rule.lastSentAt!) : 'pending',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Commit jobs card ──────────────────────────────────────────────────────────

class _CommitJobsCard extends StatelessWidget {
  const _CommitJobsCard({required this.jobs, required this.onTap});
  final List<dynamic> jobs;
  final ValueChanged<dynamic> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: jobs.take(3).toList().asMap().entries.map((e) {
          final isLast = e.key == (jobs.take(3).length - 1);
          final job = e.value;
          return InkWell(
            onTap: () => onTap(job),
            borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(18)) : BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(job.repoFullName as String, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${job.daysDone}/${job.daysTotal}d', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: job.progress as double,
                      backgroundColor: AppColors.surface3,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.indigo),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Quick actions grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.add_circle_outline_rounded, 'New Auto Message', const Color(0xFF818CF8), '/rules/new'),
      (Icons.commit_rounded, 'New Commit Job', AppColors.indigo, '/auto-commit/new'),
      (Icons.schedule_send_rounded, 'Manage Rules', const Color(0xFF60A5FA), '/rules'),
      (Icons.manage_accounts_rounded, 'Profile', const Color(0xFF34D399), '/profile'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: items.map((item) => GestureDetector(
        onTap: () => context.go(item.$4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(item.$1, size: 15, color: item.$3),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.$2, style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3), maxLines: 2)),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ── Integrations card ─────────────────────────────────────────────────────────

class _IntegrationsCard extends StatelessWidget {
  const _IntegrationsCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.code_rounded, 'GitHub', user.githubUsername.isNotEmpty),
      (Icons.chat_bubble_outline_rounded, 'Slack', user.slackConnected),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              children: [
                Icon(item.$1, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Text(item.$2, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                const Spacer(),
                if (item.$3)
                  const Row(children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: AppColors.green),
                    SizedBox(width: 4),
                    Text('Connected', style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ])
                else
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: const Row(children: [
                      Text('Connect', style: TextStyle(color: AppColors.indigoLight, fontSize: 11, fontWeight: FontWeight.w600)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppColors.indigoLight),
                    ]),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, this.color = AppColors.indigo});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count', style: TextStyle(color: color == AppColors.indigo ? AppColors.indigoLight : color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
