import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/rule_form_provider.dart';
import '../providers/rules_provider.dart';
import '../data/rules_repository.dart';
import '../data/models/rule.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/localization/app_translations.dart';

/// Create or edit a rule.
/// [ruleId] = null → create mode; [ruleId] != null → edit mode.
class RuleFormScreen extends ConsumerStatefulWidget {
  const RuleFormScreen({super.key, this.ruleId});
  final String? ruleId;

  @override
  ConsumerState<RuleFormScreen> createState() => _RuleFormScreenState();
}

class _RuleFormScreenState extends ConsumerState<RuleFormScreen> {
  final _nameCtrl = TextEditingController();
  final _exampleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _threadExampleCtrl = TextEditingController();
  final _threadCountCustomCtrl = TextEditingController();

  bool _initialized = false;
  bool _addingRepo = false;
  String _pendingRepo = '';
  String _pendingBranch = '';

  static const _days = [
    (0, 'Sun'),
    (1, 'Mon'),
    (2, 'Tue'),
    (3, 'Wed'),
    (4, 'Thu'),
    (5, 'Fri'),
    (6, 'Sat'),
  ];

  static const _notificationOptions = [
    (null, 'Off'),
    (5, '5m prior'),
    (10, '10m prior'),
    (15, '15m prior'),
    (30, '30m prior'),
    (60, '1h prior'),
  ];

  static const _timezones = [
    'UTC',
    'Asia/Dhaka',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Europe/London',
    'Europe/Berlin',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Asia/Tokyo',
    'Asia/Singapore',
    'Australia/Sydney',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  void _initForm() {
    final notifier = ref.read(ruleFormProvider.notifier);
    if (widget.ruleId != null) {
      final rules = ref.read(rulesProvider).valueOrNull ?? [];
      final existing = rules.firstWhere(
        (r) => r.id == widget.ruleId,
        orElse: () => throw Exception('Rule not found'),
      );
      notifier.init(existing);
      _nameCtrl.text = existing.name;
      _exampleCtrl.text = existing.exampleMessage;
      _noteCtrl.text = existing.note;
      _threadExampleCtrl.text = existing.threadExampleMessage ?? '';
      _threadCountCustomCtrl.text = existing.threadCountCustom ?? '';
    } else {
      notifier.init();
    }
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _exampleCtrl.dispose();
    _noteCtrl.dispose();
    _threadExampleCtrl.dispose();
    _threadCountCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(ruleFormProvider);
    final notifier = ref.read(ruleFormProvider.notifier);

    if (!form.isValid) {
      if (form.name.isEmpty) {
        notifier.setError('Rule name is required.');
      } else if (form.channelId.isEmpty) {
        notifier.setError('Select a Slack channel.');
      } else if (form.exampleMessage.isEmpty) {
        notifier.setError('Add an example message style.');
      } else if (form.runMode == 'loop' && form.daysOfWeek.isEmpty) {
        notifier.setError('Select at least one day.');
      } else {
        notifier.setError('Pick a date for one-time mode.');
      }
      return;
    }

    notifier.setSaving(true);
    try {
      final repo = ref.read(rulesRepositoryProvider);
      if (widget.ruleId == null) {
        final rule = await repo.createRule(form.toJson());
        ref.read(rulesProvider.notifier).addRule(rule);
      } else {
        final rule = await repo.updateRule(widget.ruleId!, form.toJson());
        ref.read(rulesProvider.notifier).updateRuleLocally(rule);
      }
      if (mounted) context.go('/rules');
    } catch (e) {
      notifier.setError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      notifier.setSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(ruleFormProvider);
    final channelsAsync = ref.watch(slackChannelsProvider);
    final profileAsync = ref.watch(profileProvider);
    final reposAsync = ref.watch(githubReposProvider);

    final isEdit = widget.ruleId != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final userPlan = profileAsync.valueOrNull?.effectivePlan ?? 'free';

    if (!_initialized) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: colors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isEdit ? AppTranslations.translate(context, ref, 'edit_rule') : AppTranslations.translate(context, ref, 'new_rule'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/rules'),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            children: [
              // ── Name field ──────────────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'rule_name'),
                subtitle: 'Identify this Standup rule (e.g. Mobile Sync)',
                child: TextField(
                  controller: _nameCtrl,
                  onChanged: ref.read(ruleFormProvider.notifier).setName,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Daily Standup',
                    prefixIcon: Icon(Icons.bookmark_outline_rounded, size: 20),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // ── Slack Channel select ────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'slack_channel'),
                subtitle: 'Pick the Slack channel where reports will go',
                child: channelsAsync.when(
                  loading: () => const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (err, stack) => const Text(
                    'Connect Slack first to select a channel.',
                    style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13),
                  ),
                  data: (channels) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: (form.channelId.isEmpty || !channels.any((c) => c.id == form.channelId)) ? null : form.channelId,
                        isExpanded: true,
                        hint: const Text('Select Slack channel',
                            style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13)),
                        dropdownColor: colors.surfaceContainer,
                        style: TextStyle(color: colors.onSurface, fontSize: 14),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                        ),
                        items: channels
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('#${c.name}', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final ch = channels.firstWhere((c) => c.id == id);
                          ref.read(ruleFormProvider.notifier).setChannel(ch.id, ch.name);
                        },
                      ),
                      if (form.channelId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await ref.read(rulesRepositoryProvider).testSlackChannel(form.channelId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Test message sent! Check your Slack channel.'),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed: $e'),
                                    backgroundColor: colors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text('Send test message', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── GitHub Source Selectors (Plan-conditioned) ──────────
              if (form.githubEnabled && userPlan == 'free') ...[
                _Section(
                  title: 'GitHub Source',
                  subtitle: 'Select the repository and branch to fetch commits from',
                  child: reposAsync.when(
                    loading: () => const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => const Text(
                      'Link GitHub to configure repository sources.',
                      style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13),
                    ),
                    data: (repos) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: (form.repoFullName.isEmpty || !repos.any((r) => r.fullName == form.repoFullName)) ? '' : form.repoFullName,
                          isExpanded: true,
                          hint: const Text('All repositories (default)',
                              style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13)),
                          dropdownColor: colors.surfaceContainer,
                          style: TextStyle(color: colors.onSurface, fontSize: 14),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.source_rounded, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All repositories'),
                            ),
                            ...repos.map((r) => DropdownMenuItem(
                                  value: r.fullName,
                                  child: Text(r.fullName, overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (val) {
                            ref.read(ruleFormProvider.notifier).setRepoFullName(val ?? '');
                          },
                        ),
                        if (form.repoFullName.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ref.watch(repoBranchesProvider(form.repoFullName)).when(
                                loading: () => const SizedBox(
                                  height: 40,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                                error: (err, stack) => const Text('Failed to load branches',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                data: (branches) => DropdownButtonFormField<String>(
                                  initialValue: (form.branch.isEmpty || !branches.contains(form.branch)) ? '' : form.branch,
                                  isExpanded: true,
                                  hint: const Text('Default branch',
                                      style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13)),
                                  dropdownColor: colors.surfaceContainer,
                                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.call_split_rounded, size: 20),
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Default branch'),
                                    ),
                                    ...branches.map((b) => DropdownMenuItem(
                                          value: b,
                                          child: Text(b, overflow: TextOverflow.ellipsis),
                                        )),
                                  ],
                                  onChanged: (val) {
                                    ref.read(ruleFormProvider.notifier).setBranch(val ?? '');
                                  },
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else if (form.githubEnabled) ...[
                // Premium Multi-Repo selector
                _Section(
                  title: 'GitHub Sources',
                  subtitle: 'Premium feature: monitor up to 5 specific repositories',
                  child: reposAsync.when(
                    loading: () => const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, stack) => const Text(
                      'Link GitHub to configure repository sources.',
                      style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13),
                    ),
                    data: (repos) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List existing targets
                        ...form.repoTargets.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final t = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.source_rounded, size: 16, color: Color(0xFFCAC4D0)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t.repoFullName,
                                      style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      t.branch.isEmpty ? 'default' : t.branch,
                                      style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                                    onPressed: () {
                                      ref.read(ruleFormProvider.notifier).removeRepoTarget(idx);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        if (form.repoTargets.isEmpty && !_addingRepo)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No repositories linked. Commits will be monitored across all repos.',
                                style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 12, fontStyle: FontStyle.italic)),
                          ),

                        // Inline add repo picker
                        if (_addingRepo) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _pendingRepo.isEmpty ? null : _pendingRepo,
                                  isExpanded: true,
                                  hint: const Text('Select repository',
                                      style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13)),
                                  dropdownColor: colors.surfaceContainer,
                                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.source_rounded, size: 20),
                                  ),
                                  items: repos
                                      .filter((r) => !form.repoTargets.any((t) => t.repoFullName == r.fullName))
                                      .map((r) => DropdownMenuItem(
                                            value: r.fullName,
                                            child: Text(r.fullName, overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _pendingRepo = val ?? '';
                                      _pendingBranch = '';
                                    });
                                  },
                                ),
                                if (_pendingRepo.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ref.watch(repoBranchesProvider(_pendingRepo)).when(
                                        loading: () => const SizedBox(
                                          height: 40,
                                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                        error: (err, stack) => const Text('Failed to load branches',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                        data: (branches) => DropdownButtonFormField<String>(
                                          initialValue: _pendingBranch.isEmpty ? null : _pendingBranch,
                                          isExpanded: true,
                                          hint: const Text('Default branch',
                                              style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 13)),
                                          dropdownColor: colors.surfaceContainer,
                                          style: TextStyle(color: colors.onSurface, fontSize: 14),
                                          decoration: const InputDecoration(
                                            prefixIcon: Icon(Icons.call_split_rounded, size: 20),
                                          ),
                                          items: [
                                            const DropdownMenuItem(
                                              value: '',
                                              child: Text('Default branch'),
                                            ),
                                            ...branches.map((b) => DropdownMenuItem(
                                                  value: b,
                                                  child: Text(b, overflow: TextOverflow.ellipsis),
                                                )),
                                          ],
                                          onChanged: (val) {
                                            setState(() {
                                              _pendingBranch = val ?? '';
                                            });
                                          },
                                        ),
                                      ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: _pendingRepo.isEmpty
                                            ? null
                                            : () {
                                                ref.read(ruleFormProvider.notifier).addRepoTarget(
                                                      RepoTarget(
                                                        repoFullName: _pendingRepo,
                                                        branch: _pendingBranch,
                                                      ),
                                                    );
                                                setState(() {
                                                  _addingRepo = false;
                                                  _pendingRepo = '';
                                                  _pendingBranch = '';
                                                });
                                              },
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text('Add repository', style: TextStyle(fontSize: 13)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _addingRepo = false;
                                          _pendingRepo = '';
                                          _pendingBranch = '';
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (!_addingRepo && form.repoTargets.length < 5) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _addingRepo = true;
                                  _pendingRepo = '';
                                  _pendingBranch = '';
                                });
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Link a repository', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: colors.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              // ── Run Mode select ─────────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'scheduling_mode'),
                subtitle: 'Choose recurring auto-delivery or a one-time message',
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'Recurring',
                      selected: form.runMode == 'loop',
                      icon: Icons.loop_rounded,
                      onTap: () => ref.read(ruleFormProvider.notifier).setRunMode('loop'),
                    ),
                    const SizedBox(width: 10),
                    _ModeChip(
                      label: 'One-time',
                      selected: form.runMode == 'once',
                      icon: Icons.done_rounded,
                      onTap: () => ref.read(ruleFormProvider.notifier).setRunMode('once'),
                    ),
                  ],
                ),
              ),

              // ── Days select (loop mode only) ─────────────────────────
              if (form.runMode == 'loop')
                _Section(
                  title: AppTranslations.translate(context, ref, 'active_days'),
                  subtitle: 'Schedule standup messages on specific weekdays',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _days.map(((int, String) d) {
                      final selected = form.daysOfWeek.contains(d.$1);
                      return _DayCapsule(
                        label: d.$2,
                        selected: selected,
                        onTap: () => ref.read(ruleFormProvider.notifier).toggleDay(d.$1),
                      );
                    }).toList(),
                  ),
                ),

              // ── Commit date mode (loop mode only) ────────────────────
              if (form.runMode == 'loop' && form.githubEnabled)
                _Section(
                  title: 'Commit Date',
                  subtitle: 'Which date\'s commits to include in the message',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ModeChip(
                            label: 'Today (auto)',
                            selected: form.dateMode == 'today',
                            icon: Icons.today_rounded,
                            onTap: () => ref.read(ruleFormProvider.notifier).setDateMode('today'),
                          ),
                          const SizedBox(width: 10),
                          _ModeChip(
                            label: 'Specific date',
                            selected: form.dateMode == 'specific',
                            icon: Icons.event_rounded,
                            onTap: () => ref.read(ruleFormProvider.notifier).setDateMode('specific'),
                          ),
                        ],
                      ),
                      if (form.dateMode == 'specific') ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (_, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: colors.primary,
                                    surface: colors.surfaceContainer,
                                    onSurface: colors.onSurface,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              ref.read(ruleFormProvider.notifier).setTargetDate(
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.outline, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFCAC4D0)),
                                const SizedBox(width: 12),
                                Text(
                                  form.targetDate ?? 'Pick a date',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: form.targetDate != null ? colors.onSurface : const Color(0xFFCAC4D0),
                                    fontWeight: form.targetDate != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Target date (once mode only) ────────────────────────
              if (form.runMode == 'once')
                _Section(
                  title: AppTranslations.translate(context, ref, 'target_date'),
                  subtitle: 'Select the exact date to trigger this Standup',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (_, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: colors.primary,
                              surface: colors.surfaceContainer,
                              onSurface: colors.onSurface,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        ref.read(ruleFormProvider.notifier).setTargetDate(
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.outline, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFFCAC4D0)),
                          const SizedBox(width: 12),
                          Text(
                            form.targetDate ?? 'Pick a date',
                            style: TextStyle(
                              fontSize: 14,
                              color: form.targetDate != null ? colors.onSurface : const Color(0xFFCAC4D0),
                              fontWeight: form.targetDate != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Send Time select ─────────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'send_time'),
                subtitle: 'Choose delivery time (based on timezone)',
                child: InkWell(
                  onTap: () async {
                    final parts = form.sendTime.split(':');
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: int.tryParse(parts[0]) ?? 9,
                        minute: int.tryParse(parts[1]) ?? 0,
                      ),
                      builder: (_, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: colors.primary,
                            surface: colors.surfaceContainer,
                            onSurface: colors.onSurface,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      ref.read(ruleFormProvider.notifier).setSendTime(
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                          );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outline, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFCAC4D0)),
                        const SizedBox(width: 12),
                        Text(
                          form.sendTime,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Timezone select ──────────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'timezone'),
                subtitle: 'Standup rules follow this timezone clock',
                child: DropdownButtonFormField<String>(
                  initialValue: _timezones.contains(form.timezone) ? form.timezone : 'UTC',
                  isExpanded: true,
                  dropdownColor: colors.surfaceContainer,
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.language_rounded, size: 20),
                  ),
                  items: _timezones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(ruleFormProvider.notifier).setTimezone(v);
                    }
                  },
                ),
              ),

              // ── Pre-send Notification select ──────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'notification'),
                subtitle: 'Get a push notification prior to review/edit message',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _notificationOptions.map(((int?, String) opt) {
                    final selected = form.notificationMinutes == opt.$1;
                    return _OptionCapsule(
                      label: opt.$2,
                      selected: selected,
                      onTap: () => ref.read(ruleFormProvider.notifier).setNotificationMinutes(opt.$1),
                    );
                  }).toList(),
                ),
              ),

              // ── Slack Threading Options Section ───────────────────────
              _Section(
                title: 'Slack Threading',
                subtitle: 'Send standup posts in threaded replies to clean up your Slack channels',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.outline, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.forum_outlined, size: 20, color: colors.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reply in thread', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                                const SizedBox(height: 3),
                                const Text('First send creates a parent. Next ones reply inside.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFCAC4D0))),
                              ],
                            ),
                          ),
                          Switch(
                            value: form.threadEnabled,
                            onChanged: ref.read(ruleFormProvider.notifier).setThreadEnabled,
                          ),
                        ],
                      ),
                      if (form.threadEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: colors.outline, height: 1),
                        ),
                        // Thread Reply Style dropdown
                        DropdownButtonFormField<String>(
                          initialValue: (['count', 'ai', 'date'].contains(form.threadStyle)) ? form.threadStyle : 'count',
                          isExpanded: true,
                          dropdownColor: colors.surfaceContainer,
                          style: TextStyle(color: colors.onSurface, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Thread style',
                            prefixIcon: Icon(Icons.style_rounded, size: 20),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'count', child: Text('Auto count (Day 1, 2...)', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'ai', child: Text('AI generated replies', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'date', child: Text('Date header (May 24)', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) ref.read(ruleFormProvider.notifier).setThreadStyle(val);
                          },
                        ),
                        if (form.threadStyle == 'ai') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _threadExampleCtrl,
                            maxLines: 2,
                            onChanged: ref.read(ruleFormProvider.notifier).setThreadExampleMessage,
                            decoration: const InputDecoration(
                              labelText: 'Thread AI reply template',
                              hintText: 'e.g. Day {count} standup update:\n• ...',
                              prefixIcon: Icon(Icons.psychology_outlined, size: 20),
                            ),
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                        if (form.threadStyle == 'count') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: (['number', 'date', 'date_custom'].contains(form.threadCountFormat)) ? form.threadCountFormat : 'number',
                            isExpanded: true,
                            dropdownColor: colors.surfaceContainer,
                            style: TextStyle(color: colors.onSurface, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'Count Format',
                              prefixIcon: Icon(Icons.onetwothree_rounded, size: 20),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'number', child: Text('Day N 🔥', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'date', child: Text('Date (e.g. May 24)', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'date_custom', child: Text('Date + custom text', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (val) {
                              if (val != null) ref.read(ruleFormProvider.notifier).setThreadCountFormat(val);
                            },
                          ),
                          if (form.threadCountFormat == 'date_custom') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _threadCountCustomCtrl,
                              onChanged: ref.read(ruleFormProvider.notifier).setThreadCountCustom,
                              decoration: const InputDecoration(
                                labelText: 'Custom suffix text',
                                hintText: 'e.g. standup, update, work log…',
                                prefixIcon: Icon(Icons.text_fields_rounded, size: 20),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // ── Extra switches (Toggles Box) ─────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'options'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.outline, width: 1.0),
                  ),
                  child: Column(
                    children: [
                      // GitHub commits toggle
                      Row(
                        children: [
                          Icon(Icons.code_rounded, size: 20, color: colors.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Include GitHub commits', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                                const SizedBox(height: 3),
                                const Text('Turn off to send from your quick note only.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFCAC4D0))),
                              ],
                            ),
                          ),
                          Switch(
                            value: form.githubEnabled,
                            onChanged: ref.read(ruleFormProvider.notifier).setGithubEnabled,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: colors.outline, height: 1),
                      ),
                      // Active state
                      Row(
                        children: [
                          Icon(Icons.toggle_on_outlined, size: 20, color: colors.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Active Rule', style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                                const SizedBox(height: 3),
                                const Text('Pause standup loop without deleting config.',
                                    style: TextStyle(fontSize: 12, color: Color(0xFFCAC4D0))),
                              ],
                            ),
                          ),
                          Switch(
                            value: form.isActive,
                            onChanged: ref.read(ruleFormProvider.notifier).setIsActive,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Note for AI ──────────────────────────────────────────
              _Section(
                title: 'Quick note',
                subtitle: 'Required when GitHub is off or there are no commits. Cleared after each send.',
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  onChanged: ref.read(ruleFormProvider.notifier).setNote,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Planning meeting, PR reviews, blockers on API access.',
                    prefixIcon: Icon(Icons.psychology_outlined, size: 20),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),

              // ── Example message ──────────────────────────────────────
              _Section(
                title: AppTranslations.translate(context, ref, 'example_output'),
                subtitle: 'Show the AI a template of your desired standup layout',
                child: TextField(
                  controller: _exampleCtrl,
                  maxLines: 4,
                  onChanged: ref.read(ruleFormProvider.notifier).setExampleMessage,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Yesterday I did X. Today I will focus Z. Blocking: None.',
                    prefixIcon: Icon(Icons.style_outlined, size: 20),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),

              // Error notification banner
              if (form.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      form.error!,
                      style: TextStyle(color: colors.error, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),

          // ── Symmetrical Flat Bottom Save Panel (Chunky M3 Style) ───────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: colors.outline, width: 1.2),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: form.isValid ? _submit : null,
                  icon: form.isSaving
                      ? const SizedBox.shrink()
                      : Icon(
                          isEdit ? Icons.save_rounded : Icons.rocket_launch_rounded,
                          size: 20,
                        ),
                  label: form.isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: colors.onPrimary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isEdit
                              ? AppTranslations.translate(context, ref, 'save_config')
                              : AppTranslations.translate(context, ref, 'launch_standup'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceContainer,
                    disabledForegroundColor: const Color(0xFFCAC4D0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF381E72) : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? const Color(0xFFD0BCFF) : colors.outline,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? const Color(0xFFE8DEF8) : const Color(0xFFCAC4D0),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFE8DEF8) : const Color(0xFFCAC4D0),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCapsule extends StatelessWidget {
  const _DayCapsule({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF381E72) : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? const Color(0xFFD0BCFF) : colors.outline,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFE8DEF8) : const Color(0xFFCAC4D0),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OptionCapsule extends StatelessWidget {
  const _OptionCapsule({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF381E72) : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? const Color(0xFFD0BCFF) : colors.outline,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFE8DEF8) : const Color(0xFFCAC4D0),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T element) test) {
    return where(test).toList();
  }
}
