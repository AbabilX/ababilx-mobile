import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/rule_form_provider.dart';
import '../providers/rules_provider.dart';
import '../data/rules_repository.dart';

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
        body: Center(child: CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isEdit ? 'Edit Rule' : 'New Rule',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              // ── Name field ──────────────────────────────────────────
              _Section(
                title: 'Rule Name',
                subtitle: 'Identify this Standup rule (e.g. Mobile Sync)',
                child: TextField(
                  controller: _nameCtrl,
                  onChanged: ref.read(ruleFormProvider.notifier).setName,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Daily Standup',
                    prefixIcon: Icon(Icons.bookmark_outline_rounded, size: 20, color: AppColors.textMuted),
                  ),
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),

              // ── Slack Channel select ────────────────────────────────
              _Section(
                title: 'Slack Destination Channel',
                subtitle: 'Pick the Slack channel where reports will go',
                child: channelsAsync.when(
                  loading: () => const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.indigo, strokeWidth: 2),
                    ),
                  ),
                  error: (_, _) => const Text(
                    'Connect Slack first to select a channel.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  data: (channels) => DropdownButtonFormField<String>(
                    initialValue: form.channelId.isEmpty ? null : form.channelId,
                    hint: const Text('Select Slack channel',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    dropdownColor: AppColors.surface2,
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.tag_rounded, size: 20, color: AppColors.textMuted),
                    ),
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

              // ── Run Mode select ─────────────────────────────────────
              _Section(
                title: 'Scheduling Mode',
                subtitle: 'Choose recurring auto-delivery or a one-time message',
                child: Row(
                  children: [
                    _ModeChip(
                      label: 'Recurring',
                      selected: form.runMode == 'loop',
                      icon: Icons.loop_rounded,
                      onTap: () => ref
                          .read(ruleFormProvider.notifier)
                          .setRunMode('loop'),
                    ),
                    const SizedBox(width: 10),
                    _ModeChip(
                      label: 'One-time',
                      selected: form.runMode == 'once',
                      icon: Icons.done_rounded,
                      onTap: () => ref
                          .read(ruleFormProvider.notifier)
                          .setRunMode('once'),
                    ),
                  ],
                ),
              ),

              // ── Days select (loop mode only) ─────────────────────────
              if (form.runMode == 'loop')
                _Section(
                  title: 'Select Active Days',
                  subtitle: 'Schedule standup messages on specific weekdays',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _days.map(((int, String) d) {
                      final selected = form.daysOfWeek.contains(d.$1);
                      return _DayCapsule(
                        label: d.$2,
                        selected: selected,
                        onTap: () => ref
                            .read(ruleFormProvider.notifier)
                            .toggleDay(d.$1),
                      );
                    }).toList(),
                  ),
                ),

              // ── Target date (once mode only) ────────────────────────
              if (form.runMode == 'once')
                _Section(
                  title: 'Target Delivery Date',
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Text(
                            form.targetDate ?? 'Pick a date',
                            style: TextStyle(
                              fontSize: 14,
                              color: form.targetDate != null
                                  ? AppColors.text
                                  : AppColors.textMuted,
                              fontWeight: form.targetDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Send Time select ─────────────────────────────────────
              _Section(
                title: 'Send Time',
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
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 12),
                        Text(
                          form.sendTime,
                          style: const TextStyle(
                            color: AppColors.text,
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
                title: 'Scheduler Timezone',
                subtitle: 'Standup rules follow this timezone clock',
                child: DropdownButtonFormField<String>(
                  initialValue: _timezones.contains(form.timezone)
                      ? form.timezone
                      : 'UTC',
                  dropdownColor: AppColors.surface2,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.language_rounded, size: 20, color: AppColors.textMuted),
                  ),
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

              // ── Pre-send Notification select ──────────────────────────
              _Section(
                title: 'Pre-send Review Notification',
                subtitle: 'Get a push notification prior to review/edit message',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _notificationOptions.map(((int?, String) opt) {
                    final selected = form.notificationMinutes == opt.$1;
                    return _OptionCapsule(
                      label: opt.$2,
                      selected: selected,
                      onTap: () => ref
                          .read(ruleFormProvider.notifier)
                          .setNotificationMinutes(opt.$1),
                    );
                  }).toList(),
                ),
              ),

              // ── Extra switches (Toggles Box) ─────────────────────────
              _Section(
                title: 'Standup Options',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Column(
                    children: [
                      // Post when empty
                      Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.indigoLight),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Post When Empty', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('Send message even if no code commits exist.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Switch(
                            value: form.postWhenEmpty,
                            onChanged: ref.read(ruleFormProvider.notifier).setPostWhenEmpty,
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      // Active state
                      Row(
                        children: [
                          const Icon(Icons.toggle_on_outlined, size: 20, color: AppColors.indigoLight),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Active Rule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                SizedBox(height: 2),
                                Text('Pause standup loop without deleting config.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
                title: 'AI Standup Guidelines',
                subtitle: 'Instruct the AI on writing tone, blockers, or highlights',
                child: TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  onChanged: ref.read(ruleFormProvider.notifier).setNote,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Mention blockers in bold. Keep bullet points ultra-concise.',
                    prefixIcon: Icon(Icons.psychology_outlined, size: 20, color: AppColors.textMuted),
                  ),
                  style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.5),
                ),
              ),

              // ── Example message ──────────────────────────────────────
              _Section(
                title: 'Example Output Style',
                subtitle: 'Show the AI a template of your desired standup layout',
                child: TextField(
                  controller: _exampleCtrl,
                  maxLines: 4,
                  onChanged:
                      ref.read(ruleFormProvider.notifier).setExampleMessage,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Yesterday I did X. Today I will focus Z. Blocking: None.',
                    prefixIcon: Icon(Icons.style_outlined, size: 20, color: AppColors.textMuted),
                  ),
                  style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.5),
                ),
              ),

              // Error notification banner
              if (form.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.red.withOpacity(0.2),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      form.error!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),

          // ── Frosted Glassmorphic Bottom Save Panel ─────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withOpacity(0.75),
                    border: const Border(
                      top: BorderSide(color: AppColors.border, width: 0.8),
                    ),
                  ),
                  child: GradientButton(
                    label: isEdit ? 'Save Standup Config' : 'Launch Auto Standup',
                    icon: isEdit ? Icons.save_rounded : Icons.rocket_launch_rounded,
                    isLoading: form.isSaving,
                    onPressed: form.isValid ? _submit : null,
                    width: double.infinity,
                    height: 50,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.indigo.withOpacity(0.08) : AppColors.surface2,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: selected ? AppColors.indigo : AppColors.border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.indigoLight : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.indigoLight : AppColors.textMuted,
                  fontSize: 13,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo.withOpacity(0.08) : AppColors.surface2,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.indigoLight : AppColors.textMuted,
            fontSize: 13,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo.withOpacity(0.08) : AppColors.surface2,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.indigoLight : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
