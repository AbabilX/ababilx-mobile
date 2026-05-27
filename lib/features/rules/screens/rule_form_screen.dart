import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../data/models/rule.dart';
import '../providers/rule_form_provider.dart';
import '../providers/rules_provider.dart';
import '../../../features/rules/data/models/rule_message.dart';

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

  bool _initialized = false;

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
    (5, '5 min'),
    (10, '10 min'),
    (15, '15 min'),
    (30, '30 min'),
    (60, '1 hour'),
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
      // Edit mode — find the rule from cache
      final rules = ref.read(rulesProvider).valueOrNull ?? [];
      final existing = rules.firstWhere(
        (r) => r.id == widget.ruleId,
        orElse: () => throw Exception('Rule not found'),
      );
      notifier.init(existing);
      _nameCtrl.text = existing.name;
      _exampleCtrl.text = existing.exampleMessage;
      _noteCtrl.text = existing.note;
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
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(ruleFormProvider);
    final notifier = ref.read(ruleFormProvider.notifier);

    if (!form.isValid) {
      notifier.setError('Name, channel, and at least one day are required.');
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
    final isEdit = widget.ruleId != null;

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.indigo)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Rule' : 'New Rule'),
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              // ── Name ────────────────────────────────────────────────
              _Section(
                title: 'Rule Name',
                child: TextField(
                  controller: _nameCtrl,
                  onChanged: ref.read(ruleFormProvider.notifier).setName,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Daily Standup',
                  ),
                  style: const TextStyle(color: AppColors.text),
                ),
              ),

              // ── Slack Channel ────────────────────────────────────────
              _Section(
                title: 'Slack Channel',
                child: channelsAsync.when(
                  loading: () => const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.indigo, strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => const Text(
                    'Connect Slack first to select a channel.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  data: (channels) => DropdownButtonFormField<String>(
                    value: form.channelId.isEmpty ? null : form.channelId,
                    hint: const Text('Select channel',
                        style: TextStyle(color: AppColors.textMuted)),
                    dropdownColor: AppColors.surface2,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(),
                    items: channels
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('#${c.name}'),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final ch =
                          channels.firstWhere((c) => c.id == id);
                      ref
                          .read(ruleFormProvider.notifier)
                          .setChannel(ch.id, ch.name);
                    },
                  ),
                ),
              ),

              // ── Run Mode ────────────────────────────────────────────
              _Section(
                title: 'Run Mode',
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'Recurring',
                      selected: form.runMode == 'loop',
                      onTap: () => ref
                          .read(ruleFormProvider.notifier)
                          .setRunMode('loop'),
                    ),
                    const SizedBox(width: 10),
                    _ModeChip(
                      label: 'Once',
                      selected: form.runMode == 'once',
                      onTap: () => ref
                          .read(ruleFormProvider.notifier)
                          .setRunMode('once'),
                    ),
                  ],
                ),
              ),

              // ── Days (loop mode only) ────────────────────────────────
              if (form.runMode == 'loop')
                _Section(
                  title: 'Days of Week',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _days.map(((int, String) d) {
                      final selected = form.daysOfWeek.contains(d.$1);
                      return FilterChip(
                        label: Text(d.$2),
                        selected: selected,
                        onSelected: (_) => ref
                            .read(ruleFormProvider.notifier)
                            .toggleDay(d.$1),
                        selectedColor: AppColors.indigoGlow,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.indigoLight
                              : AppColors.textMuted,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.indigo
                              : AppColors.border,
                        ),
                        checkmarkColor: AppColors.indigoLight,
                      );
                    }).toList(),
                  ),
                ),

              // ── Target date (once mode) ──────────────────────────────
              if (form.runMode == 'once')
                _Section(
                  title: 'Target Date',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (_, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.indigo,
                              surface: AppColors.surface2,
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            const Border.fromBorderSide(BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 10),
                          Text(
                            form.targetDate ?? 'Pick a date',
                            style: TextStyle(
                              color: form.targetDate != null
                                  ? AppColors.text
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Send Time ────────────────────────────────────────────
              _Section(
                title: 'Send Time',
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
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.indigo,
                            surface: AppColors.surface2,
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: const Border.fromBorderSide(
                          BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Text(
                          form.sendTime,
                          style: const TextStyle(color: AppColors.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Timezone ─────────────────────────────────────────────
              _Section(
                title: 'Timezone',
                child: DropdownButtonFormField<String>(
                  value: _timezones.contains(form.timezone)
                      ? form.timezone
                      : 'UTC',
                  dropdownColor: AppColors.surface2,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: const InputDecoration(),
                  items: _timezones
                      .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(ruleFormProvider.notifier).setTimezone(v);
                    }
                  },
                ),
              ),

              // ── Notification timing ──────────────────────────────────
              _Section(
                title: 'Pre-send Notification',
                subtitle:
                    'Get notified before the message sends so you can review it.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _notificationOptions.map(((int?, String) opt) {
                    final selected = form.notificationMinutes == opt.$1;
                    return ChoiceChip(
                      label: Text(opt.$2),
                      selected: selected,
                      onSelected: (_) => ref
                          .read(ruleFormProvider.notifier)
                          .setNotificationMinutes(opt.$1),
                      selectedColor: AppColors.indigoGlow,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.indigoLight
                            : AppColors.textMuted,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: selected
                            ? AppColors.indigo
                            : AppColors.border,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Post when empty ──────────────────────────────────────
              _Section(
                title: 'Post When Empty',
                subtitle:
                    'Send message even when there are no commits that day.',
                child: Switch(
                  value: form.postWhenEmpty,
                  onChanged: ref.read(ruleFormProvider.notifier).setPostWhenEmpty,
                  activeColor: AppColors.indigo,
                ),
              ),

              // ── Active toggle ────────────────────────────────────────
              _Section(
                title: 'Active',
                subtitle: 'Disable to pause this rule without deleting it.',
                child: Switch(
                  value: form.isActive,
                  onChanged: ref.read(ruleFormProvider.notifier).setIsActive,
                  activeColor: AppColors.indigo,
                ),
              ),

              // ── AI Note ──────────────────────────────────────────────
              _Section(
                title: 'Note for AI',
                subtitle:
                    'Extra context for the AI when generating your standup message.',
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  onChanged: ref.read(ruleFormProvider.notifier).setNote,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Always mention blockers. Keep it concise.',
                  ),
                  style:
                      const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),

              // ── Example message ──────────────────────────────────────
              _Section(
                title: 'Example Message Style',
                subtitle:
                    'Show the AI how you want the message to sound.',
                child: TextField(
                  controller: _exampleCtrl,
                  maxLines: 4,
                  onChanged:
                      ref.read(ruleFormProvider.notifier).setExampleMessage,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Yesterday I worked on X. Today I will do Y. No blockers.',
                  ),
                  style:
                      const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),

              // Error
              if (form.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      form.error!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),

          // Bottom save button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.bg],
                ),
              ),
              child: GradientButton(
                label: isEdit ? 'Save Changes' : 'Create Rule',
                icon: isEdit ? Icons.save_outlined : Icons.add,
                isLoading: form.isSaving,
                onPressed: form.isValid ? _submit : null,
                width: double.infinity,
                height: 52,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
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
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigoGlow : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.indigo : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.indigoLight : AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
