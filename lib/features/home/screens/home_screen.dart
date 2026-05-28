import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../auto_commit/providers/auto_commit_provider.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/providers/profile_provider.dart';
import '../../rules/data/models/rule.dart';
import '../../rules/data/rules_repository.dart';
import '../../rules/providers/rules_provider.dart';
import '../data/activity_repository.dart';
import '../providers/activity_provider.dart';

// ── M3 tonal palette constants (complement global ColorScheme) ────────────────
const _kIndigo       = Color(0xFF6366F1);
const _kIndigoCont   = Color(0xFF381E72);
const _kIndigoOnCont = Color(0xFFE8DEF8);
const _kGreenCont    = Color(0xFF005224);
const _kGreenOnCont  = Color(0xFFC1F8C8);
const _kAmberCont    = Color(0xFF7A4E00);
const _kAmberOnCont  = Color(0xFFFFDF9E);
const _kBlueCont     = Color(0xFF1D3066);
const _kBlueOnCont   = Color(0xFFD4E3FF);
const _kGreen        = Color(0xFF22C55E);
const _kMuted        = Color(0xFFCAC4D0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _pager = PageController(viewportFraction: 0.92);
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

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _TopBar(user: user, onAvatarTap: () => context.go('/profile')),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
        color: colors.primary,
        backgroundColor: colors.surfaceContainerLow,
        displacement: 20,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Overview title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Text(
                  'Overview',
                  style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: -0.5),
                ),
              ),
            ),

            // ── Stat row ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Active Rules',
                        value: '${activeRules.length}',
                        subLabel: 'of ${rules.length} total',
                        icon: Icons.bolt_rounded,
                        iconBg: _kGreenCont,
                        iconFg: _kGreenOnCont,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'This Week',
                        value: '${activity.totalThisWeek}',
                        subLabel: '${activity.totalStandups}s · ${activity.totalCommits}c',
                        icon: Icons.bar_chart_rounded,
                        iconBg: _kIndigoCont,
                        iconFg: _kIndigoOnCont,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Activity bar chart ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _ActivityCard(activity: activity),
              ),
            ),

            // ── Today's standups pager ────────────────────────────────────
            if (todayRules.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: _SectionHeader(
                    icon: Icons.today_rounded,
                    iconBg: _kIndigoCont,
                    iconFg: _kIndigoOnCont,
                    title: "Today's Standups",
                    badge: todayRules.length,
                    trailing: todayRules.length > 1
                        ? Text(
                            '${_page + 1} / ${todayRules.length}',
                            style: const TextStyle(color: _kMuted, fontSize: 11),
                          )
                        : null,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 258,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: todayRules.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _StandupCard(
                      rule: todayRules[i],
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
                            color: i == _page ? _kIndigo : Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            // ── Active rules list ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: _SectionHeader(
                  icon: Icons.bolt_rounded,
                  iconBg: _kGreenCont,
                  iconFg: _kGreenOnCont,
                  title: 'Active Rules',
                  badge: activeRules.isNotEmpty ? activeRules.length : null,
                  trailing: GestureDetector(
                    onTap: () => context.go('/rules'),
                    child: const Text(
                      'See all ›',
                      style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
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

            // ── Active commit jobs ────────────────────────────────────────
            if (activeJobs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: _SectionHeader(
                    icon: Icons.commit_rounded,
                    iconBg: _kBlueCont,
                    iconFg: _kBlueOnCont,
                    title: 'Commit Jobs',
                    badge: activeJobs.length,
                    trailing: GestureDetector(
                      onTap: () => context.go('/auto-commit'),
                      child: const Text(
                        'See all ›',
                        style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
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

            // ── Quick actions ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                child: _SectionHeader(
                  icon: Icons.grid_view_rounded,
                  iconBg: _kAmberCont,
                  iconFg: _kAmberOnCont,
                  title: 'Quick Actions',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const _QuickActionsGrid(),
              ),
            ),

            // ── Integrations ──────────────────────────────────────────────
            if (user != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  child: _SectionHeader(
                    icon: Icons.hub_rounded,
                    iconBg: _kBlueCont,
                    iconFg: _kBlueOnCont,
                    title: 'Integrations',
                  ),
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

// ── Top bar ───────────────────────────────────────────────────────────────────

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kIndigoCont,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.bolt_rounded, color: _kIndigoOnCont, size: 21),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: const TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  user == null ? 'AbabilX' : user!.name.split(' ').first,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.outline, width: 1.5),
                      color: colors.surfaceContainerLow,
                    ),
                    child: ClipOval(
                      child: user != null && user!.avatarUrl.isNotEmpty
                          ? Image.network(user!.avatarUrl, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded, color: _kMuted, size: 20),
                    ),
                  ),
                  if (user != null && user!.plan != 'free')
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _kAmberOnCont,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 1.5),
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

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    this.badge,
    this.trailing,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final int? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconFg, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(letterSpacing: -0.2),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$badge',
              style: TextStyle(color: iconFg, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
  });
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: iconFg.withValues(alpha: 0.65), fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 20, color: iconFg.withValues(alpha: 0.75)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: iconFg,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subLabel,
            style: TextStyle(color: iconFg.withValues(alpha: 0.55), fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    final colors = Theme.of(context).colorScheme;
    final maxVal = activity.days.map((d) => d.total).fold(0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal < 1 ? 1 : maxVal;
    final isLoading = ref.watch(activityProvider).isLoading;
    final isMonthly = activity.isMonthly;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity',
                style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              // Period toggle — M3 chip style matching rules_screen
              GestureDetector(
                onTap: isLoading
                    ? null
                    : () {
                        final next = isMonthly ? 'weekly' : 'monthly';
                        ref.read(activityProvider.notifier).setPeriod(next);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMonthly ? _kIndigoCont : colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: isMonthly ? _kIndigoCont : colors.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: _kIndigoOnCont),
                        )
                      else
                        Icon(
                          isMonthly ? Icons.calendar_month_rounded : Icons.calendar_view_week_rounded,
                          size: 13,
                          color: isMonthly ? _kIndigoOnCont : _kMuted,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        isMonthly ? 'Monthly' : 'Weekly',
                        style: TextStyle(
                          color: isMonthly ? _kIndigoOnCont : _kMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz_rounded, size: 13, color: isMonthly ? _kIndigoOnCont : _kMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${activity.totalThisWeek}',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1,
                  ),
                ),
                TextSpan(
                  text: ' actions',
                  style: TextStyle(color: _kMuted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${activity.totalStandups} standups  ·  ${activity.totalCommits} commits',
            style: const TextStyle(color: _kMuted, fontSize: 11),
          ),

          const SizedBox(height: 16),

          isMonthly
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
    final colors = Theme.of(context).colorScheme;
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
                          ? _kIndigo
                          : d.total == 0
                              ? colors.surfaceContainer
                              : _kIndigo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dowLabels[d.day],
                style: TextStyle(
                  color: isToday ? _kIndigoOnCont : _kMuted,
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
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 80,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: activity.days.map((d) {
            final isToday = d.day == activity.today;
            final barH = d.total == 0 ? 6.0 : (d.total / effectiveMax * 56).clamp(8.0, 56.0);
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
                              ? _kIndigo
                              : d.total == 0
                                  ? colors.surfaceContainer
                                  : _kIndigo.withValues(alpha: 0.4),
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
                        color: isToday ? _kIndigoOnCont : _kMuted,
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
  const _StandupCard({required this.rule, required this.onEdit});
  final Rule rule;
  final VoidCallback onEdit;

  bool get _sentToday {
    final last = rule.lastSentAt;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _kGreenCont,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.record_voice_over_rounded, size: 20, color: _kGreenOnCont),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.name,
                        style: TextStyle(color: colors.onSurface, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _kIndigoCont, borderRadius: BorderRadius.circular(100)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tag_rounded, size: 10, color: _kIndigoOnCont),
                                const SizedBox(width: 3),
                                Text(
                                  rule.channelName.isNotEmpty ? rule.channelName : rule.channelId,
                                  style: const TextStyle(color: _kIndigoOnCont, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(rule.sendTime, style: const TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: colors.outline),
                    ),
                    child: const Icon(Icons.open_in_new_rounded, size: 14, color: _kMuted),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Already sent warning
            if (_sentToday)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kAmberCont,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: _kAmberOnCont),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Already sent today — sending again will duplicate',
                        style: TextStyle(color: _kAmberOnCont, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Repo targets or single repo
            if (rule.repoTargets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: rule.repoTargets.take(3).map((t) {
                    final short = t.repoFullName.contains('/') ? t.repoFullName.split('/').last : t.repoFullName;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.outline),
                      ),
                      child: Text(short, style: const TextStyle(color: _kMuted, fontSize: 11, fontFamily: 'monospace')),
                    );
                  }).toList(),
                ),
              )
            else if (rule.repoFullName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Text(
                    rule.repoFullName,
                    style: const TextStyle(color: _kMuted, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),

            const Spacer(),

            // Send Now button
            GradientButton(
              label: 'Send Now',
              icon: Icons.send_rounded,
              width: double.infinity,
              height: 44,
              onPressed: () => _SendNowSheet.show(context, rule),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Send Now bottom sheet ─────────────────────────────────────────────────────

enum _SendStep { warn, previewLoading, preview, sending, done }

class _SendNowSheet extends ConsumerStatefulWidget {
  const _SendNowSheet({required this.rule});
  final Rule rule;

  static Future<void> show(BuildContext context, Rule rule) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendNowSheet(rule: rule),
    );
  }

  @override
  ConsumerState<_SendNowSheet> createState() => _SendNowSheetState();
}

class _SendNowSheetState extends ConsumerState<_SendNowSheet> {
  _SendStep _step = _SendStep.warn;
  String? _error;
  int _regenCount = 0;
  static const _maxRegen = 5;
  late final TextEditingController _previewCtrl = TextEditingController();

  @override
  void dispose() {
    _previewCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePreview() async {
    setState(() { _step = _SendStep.previewLoading; _error = null; });
    try {
      final text = await ref.read(rulesRepositoryProvider).previewRule(widget.rule.id);
      _previewCtrl.text = text;
      setState(() => _step = _SendStep.preview);
    } catch (e) {
      setState(() { _error = e.toString(); _step = _SendStep.warn; });
    }
  }

  Future<void> _regenerate() async {
    if (_regenCount >= _maxRegen) return;
    setState(() { _regenCount++; _error = null; });
    try {
      final text = await ref.read(rulesRepositoryProvider).previewRule(widget.rule.id);
      _previewCtrl.text = text;
      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _send() async {
    setState(() { _step = _SendStep.sending; _error = null; });
    try {
      await ref.read(rulesRepositoryProvider).triggerRule(widget.rule.id, message: _previewCtrl.text.trim());
      setState(() => _step = _SendStep.done);
      await ref.read(rulesProvider.notifier).refresh();
    } catch (e) {
      setState(() { _error = e.toString(); _step = _SendStep.preview; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: colors.outline, borderRadius: BorderRadius.circular(2)),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _kGreenCont, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.send_rounded, size: 19, color: _kGreenOnCont),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _step == _SendStep.done ? 'Sent!' : (_step == _SendStep.preview || _step == _SendStep.sending) ? 'Review message' : 'Send standup now?',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                            Text(
                              '#${widget.rule.channelName.isNotEmpty ? widget.rule.channelName : widget.rule.channelId}',
                              style: const TextStyle(color: _kMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (_step != _SendStep.sending && _step != _SendStep.previewLoading)
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(color: colors.surfaceContainer, borderRadius: BorderRadius.circular(100)),
                            child: const Icon(Icons.close_rounded, size: 16, color: _kMuted),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Step: warn
                  if (_step == _SendStep.warn) ...[
                    Text(
                      'Tap Continue to generate an AI preview of the message before sending.',
                      style: TextStyle(color: _kMuted, fontSize: 13, height: 1.5),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientButton(
                            label: 'Continue',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _generatePreview,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Step: preview loading
                  if (_step == _SendStep.previewLoading) ...[
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kIndigo),
                            ),
                            SizedBox(height: 10),
                            Text('Generating from your commits…', style: TextStyle(color: _kMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Step: preview
                  if (_step == _SendStep.preview || _step == _SendStep.sending) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outline),
                      ),
                      child: TextField(
                        controller: _previewCtrl,
                        maxLines: 6,
                        enabled: _step == _SendStep.preview,
                        style: TextStyle(color: colors.onSurface, fontSize: 13, height: 1.6),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(14),
                          border: InputBorder.none,
                          hintText: 'AI message will appear here…',
                        ),
                      ),
                    ),
                    if (_step == _SendStep.preview) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _regenCount < _maxRegen ? _regenerate : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 14, color: _regenCount < _maxRegen ? _kIndigo : _kMuted),
                                const SizedBox(width: 4),
                                Text(
                                  'Regenerate AI',
                                  style: TextStyle(color: _regenCount < _maxRegen ? _kIndigo : _kMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_maxRegen - _regenCount} / $_maxRegen left',
                            style: const TextStyle(color: _kMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                        child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_step == _SendStep.preview)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GradientButton(
                              label: 'Confirm & Send',
                              icon: Icons.send_rounded,
                              onPressed: _previewCtrl.text.trim().isEmpty ? null : _send,
                            ),
                          ),
                        ],
                      )
                    else
                      GradientButton(
                        label: 'Sending…',
                        isLoading: true,
                        width: double.infinity,
                        onPressed: null,
                      ),
                  ],

                  // Step: done
                  if (_step == _SendStep.done) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _kGreenCont, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: _kGreenOnCont, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Message sent to Slack!', style: TextStyle(color: _kGreenOnCont, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GradientButton(
                      label: 'Close',
                      width: double.infinity,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rules card ────────────────────────────────────────────────────────────────

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
    final colors = Theme.of(context).colorScheme;

    if (rules.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt_outlined, color: _kMuted, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('No active rules', style: TextStyle(color: _kMuted, fontSize: 13))),
            GestureDetector(
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kIndigoCont,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text('Create', style: TextStyle(color: _kIndigoOnCont, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: rules.take(4).toList().asMap().entries.map((e) {
          final isFirst = e.key == 0;
          final isLast = e.key == (rules.take(4).length - 1);
          final rule = e.value;
          return InkWell(
            onTap: () => onTap(rule),
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(28) : Radius.zero,
              topRight: isFirst ? const Radius.circular(28) : Radius.zero,
              bottomLeft: isLast ? const Radius.circular(28) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(28) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${rule.channelName.isNotEmpty ? rule.channelName : rule.channelId}  ·  ${rule.sendTime}',
                          style: const TextStyle(color: _kMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    rule.lastSentAt != null ? _timeAgo(rule.lastSentAt!) : 'pending',
                    style: const TextStyle(color: _kMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: _kMuted),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: jobs.take(3).toList().asMap().entries.map((e) {
          final isFirst = e.key == 0;
          final isLast = e.key == (jobs.take(3).length - 1);
          final job = e.value;
          return InkWell(
            onTap: () => onTap(job),
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(28) : Radius.zero,
              topRight: isFirst ? const Radius.circular(28) : Radius.zero,
              bottomLeft: isLast ? const Radius.circular(28) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(28) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.repoFullName as String,
                          style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Text('${job.daysDone}/${job.daysTotal}d', style: const TextStyle(color: _kMuted, fontSize: 11)),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: _kMuted),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: job.progress as double,
                      backgroundColor: colors.surfaceContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kIndigo),
                      minHeight: 4,
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
    const items = [
      (Icons.add_circle_outline_rounded, 'New Auto Message', _kIndigoCont, _kIndigoOnCont, '/rules/new'),
      (Icons.commit_rounded, 'New Commit Job', _kBlueCont, _kBlueOnCont, '/auto-commit/new'),
      (Icons.schedule_send_rounded, 'Manage Rules', _kGreenCont, _kGreenOnCont, '/rules'),
      (Icons.manage_accounts_rounded, 'Profile', _kAmberCont, _kAmberOnCont, '/profile'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: items.map((item) => GestureDetector(
        onTap: () => context.go(item.$5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.$3,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.$1, size: 26, color: item.$4),
              Text(
                item.$2,
                style: TextStyle(
                  color: item.$4,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
              ),
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
    final colors = Theme.of(context).colorScheme;
    final items = [
      (Icons.code_rounded, 'GitHub', user.githubUsername.isNotEmpty),
      (Icons.chat_bubble_outline_rounded, 'Slack', user.slackConnected),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.$1, size: 18, color: _kMuted),
                ),
                const SizedBox(width: 12),
                Text(item.$2, style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (item.$3)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kGreenCont,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 12, color: _kGreenOnCont),
                        SizedBox(width: 4),
                        Text('Connected', style: TextStyle(color: _kGreenOnCont, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kIndigoCont,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Connect', style: TextStyle(color: _kIndigoOnCont, fontSize: 11, fontWeight: FontWeight.w700)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _kIndigoOnCont),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
