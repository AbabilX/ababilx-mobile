import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../rules/data/models/github_repo.dart';
import '../../rules/providers/rules_provider.dart';
import '../data/models/auto_commit_job.dart';
import '../providers/auto_commit_provider.dart';

class AutoCommitFormScreen extends ConsumerStatefulWidget {
  const AutoCommitFormScreen({super.key, this.jobId});
  final String? jobId;

  @override
  ConsumerState<AutoCommitFormScreen> createState() => _AutoCommitFormScreenState();
}

class _AutoCommitFormScreenState extends ConsumerState<AutoCommitFormScreen> {
  int _selectedDays = 1;
  int _selectedCommitsPerDay = 1;
  String? _selectedRepo;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.jobId != null;
  AutoCommitJob? _editJob;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditJob());
    }
  }

  void _loadEditJob() {
    final meta = ref.read(autoCommitProvider).valueOrNull;
    if (meta == null) return;
    final job = meta.jobs.where((j) => j.id == widget.jobId).firstOrNull;
    if (job != null) {
      setState(() {
        _editJob = job;
        _selectedCommitsPerDay = job.commitsPerDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(autoCommitProvider);
    final reposAsync = ref.watch(githubReposProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return metaAsync.when(
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.textMuted))),
      ),
      data: (meta) {
        final dayOptions = meta.dayOptions.isEmpty ? List.generate(meta.maxDays, (i) => i + 1) : meta.dayOptions;
        final commitsOptions = meta.commitsPerDayOptions.isEmpty ? [1, 2] : meta.commitsPerDayOptions;

        // Clamp selections to available options
        if (!dayOptions.contains(_selectedDays)) _selectedDays = dayOptions.first;
        if (!commitsOptions.contains(_selectedCommitsPerDay)) _selectedCommitsPerDay = commitsOptions.first;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Text(
              _isEdit ? 'Edit Job' : 'New Auto-Commit Job',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEdit && !meta.canCreate)
                  _LimitWarning(meta: meta),

                if (!_isEdit) ...[
                  _SectionLabel(label: 'Duration', subtitle: 'How many days to run commits'),
                  _DropdownPicker(
                    options: dayOptions,
                    selected: _selectedDays,
                    onSelect: (v) => setState(() => _selectedDays = v!),
                    labelBuilder: (v) => '$v day${v > 1 ? 's' : ''}',
                  ),
                  const SizedBox(height: 24),
                ],

                _SectionLabel(
                  label: 'Commits per Day',
                  subtitle: meta.isPremium ? 'Up to ${commitsOptions.last} (premium)' : 'Up to ${commitsOptions.last} (free)',
                ),
                _ChipPicker(
                  options: commitsOptions,
                  selected: _selectedCommitsPerDay,
                  onSelect: (v) => setState(() => _selectedCommitsPerDay = v),
                  labelBuilder: (v) => '$v/day',
                ),
                const SizedBox(height: 24),

                if (!_isEdit) ...[
                  _SectionLabel(
                    label: 'Repository (Optional)',
                    subtitle: 'Leave blank to auto-create a new repo',
                  ),
                  reposAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.surface2,
                        color: AppColors.indigo,
                        minHeight: 2,
                      ),
                    ),
                    error: (_, e) => const SizedBox.shrink(),
                    data: (repos) => _RepoPicker(
                      repos: repos,
                      selected: _selectedRepo,
                      onSelect: (v) => setState(() => _selectedRepo = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_isEdit && _editJob != null) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only commits/day can be changed after a job is created.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                GradientButton(
                  label: _isEdit ? 'Save Changes' : 'Create Job',
                  icon: _isEdit ? Icons.save_rounded : Icons.rocket_launch_rounded,
                  isLoading: _submitting,
                  width: double.infinity,
                  onPressed: (!meta.canCreate && !_isEdit) ? null : () => _submit(meta),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(AutoCommitMeta meta) async {
    setState(() { _submitting = true; _error = null; });
    try {
      if (_isEdit) {
        await ref.read(autoCommitProvider.notifier).patchJob(
          widget.jobId!,
          _selectedCommitsPerDay,
        );
      } else {
        await ref.read(autoCommitProvider.notifier).createJob(
          daysTotal: _selectedDays,
          commitsPerDay: _selectedCommitsPerDay,
          repoFullName: _selectedRepo,
        );
      }
      if (mounted) context.go('/auto-commit');
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('free_limit_exceeded')) {
        msg = 'Free monthly limit reached. Upgrade to premium for more.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.subtitle});
  final String label;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _ChipPicker extends StatelessWidget {
  const _ChipPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelBuilder,
  });
  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final String Function(int) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((v) {
        final isSelected = v == selected;
        return GestureDetector(
          onTap: () => onSelect(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.indigo.withValues(alpha: 0.15) : AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.indigo.withValues(alpha: 0.6) : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelBuilder(v),
              style: TextStyle(
                color: isSelected ? AppColors.indigoLight : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RepoPicker extends StatelessWidget {
  const _RepoPicker({required this.repos, required this.selected, required this.onSelect});
  final List<GitHubRepo> repos;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          borderRadius: BorderRadius.circular(20),
          style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w500),
          hint: const Text(
            'Auto-create new repo',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          onChanged: onSelect,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Auto-create new repo', style: TextStyle(color: AppColors.textMuted)),
            ),
            ...repos.map((repo) => DropdownMenuItem<String?>(
              value: repo.fullName,
              child: Text(repo.fullName, overflow: TextOverflow.ellipsis),
            )),
          ],
        ),
      ),
    );
  }
}

class _DropdownPicker extends StatelessWidget {
  const _DropdownPicker({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.labelBuilder,
  });
  final List<int> options;
  final int selected;
  final ValueChanged<int?> onSelect;
  final String Function(int) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.surface2,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          borderRadius: BorderRadius.circular(20),
          style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
          onChanged: onSelect,
          items: options
              .map((v) => DropdownMenuItem<int>(
                    value: v,
                    child: Text(labelBuilder(v)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _LimitWarning extends StatelessWidget {
  const _LimitWarning({required this.meta});
  final AutoCommitMeta meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: AppColors.red.withValues(alpha: 0.3),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.red, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Monthly free limit reached (3 days). Upgrade to create more jobs.',
                style: TextStyle(color: AppColors.red, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
