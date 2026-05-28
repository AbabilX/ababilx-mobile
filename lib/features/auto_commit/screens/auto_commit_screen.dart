import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/models/auto_commit_job.dart';
import '../providers/auto_commit_provider.dart';

class AutoCommitScreen extends ConsumerWidget {
  const AutoCommitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(autoCommitProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Auto Commit',
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
            onPressed: () => ref.read(autoCommitProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: metaAsync.maybeWhen(
        data: (meta) => meta.canCreate
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/auto-commit/new'),
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'New Job',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              )
            : null,
        orElse: () => null,
      ),
      body: metaAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
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
                child: Icon(Icons.error_outline_rounded, size: 36, color: colors.error),
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
                onPressed: () => ref.read(autoCommitProvider.notifier).refresh(),
              ),
            ],
          ),
        ),
        data: (meta) => RefreshIndicator(
          onRefresh: () => ref.read(autoCommitProvider.notifier).refresh(),
          color: AppColors.indigo,
          backgroundColor: AppColors.surface2,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _UsageBanner(meta: meta),
              ),
              if (meta.jobs.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(
                    canCreate: meta.canCreate,
                    onTap: () => context.go('/auto-commit/new'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _JobCard(
                        job: meta.jobs[i],
                        onEdit: () => context.go('/auto-commit/${meta.jobs[i].id}/edit'),
                        onDelete: () => _confirmDelete(context, ref, meta.jobs[i].id),
                      ),
                      childCount: meta.jobs.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Job', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will stop all future commits for this job. Cannot be undone.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(autoCommitProvider.notifier).deleteJob(id);
    }
  }
}

class _UsageBanner extends StatelessWidget {
  const _UsageBanner({required this.meta});
  final AutoCommitMeta meta;

  @override
  Widget build(BuildContext context) {
    if (meta.isPremium) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.amber, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Premium — Unlimited auto commits',
                style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final fraction = (meta.monthlyUsed / meta.monthlyLimit).clamp(0.0, 1.0);
    final full = meta.remaining == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Usage',
                  style: TextStyle(
                    color: full ? AppColors.red : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${meta.monthlyUsed} / ${meta.monthlyLimit} days',
                  style: TextStyle(
                    color: full ? AppColors.red : AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: AppColors.surface3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  full ? AppColors.red : AppColors.indigo,
                ),
                minHeight: 6,
              ),
            ),
            if (full) ...[
              const SizedBox(height: 6),
              const Text(
                'Free limit reached for this month. Upgrade for unlimited commits.',
                style: TextStyle(color: AppColors.red, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onEdit, required this.onDelete});
  final AutoCommitJob job;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isComplete = !job.isActive || job.daysDone >= job.daysTotal;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: job.isActive ? onEdit : null,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.repoFullName,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.commitsPerDay} commit${job.commitsPerDay > 1 ? 's' : ''}/day',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(isComplete: isComplete, isActive: job.isActive),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.textMuted,
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${job.daysDone} / ${job.daysTotal} days',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isComplete
                      ? 'Completed'
                      : 'Next: ${job.nextCommitDate}',
                  style: TextStyle(
                    color: isComplete ? AppColors.green : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: job.progress,
                backgroundColor: AppColors.surface3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? AppColors.green : AppColors.indigo,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isComplete, required this.isActive});
  final bool isComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (isComplete) {
      color = AppColors.green;
      label = 'Done';
    } else if (isActive) {
      color = AppColors.indigo;
      label = 'Active';
    } else {
      color = AppColors.textMuted;
      label = 'Paused';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canCreate, required this.onTap});
  final bool canCreate;
  final VoidCallback onTap;

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
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.commit_rounded, size: 40, color: AppColors.indigo),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Auto-Commit Jobs',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a job to automatically commit to GitHub every day.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (canCreate) ...[
              const SizedBox(height: 28),
              GradientButton(
                label: 'Create First Job',
                icon: Icons.add_rounded,
                onPressed: onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
