import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../providers/rules_provider.dart';

class RuleHistoryScreen extends ConsumerWidget {
  const RuleHistoryScreen({super.key, required this.ruleId});
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(ruleMessagesProvider(ruleId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Message History'),
        leading: const BackButton(),
      ),
      body: messagesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.indigo)),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(color: AppColors.textMuted)),
        ),
        data: (messages) => messages.isEmpty
            ? const EmptyState(
                icon: Icons.history_outlined,
                title: 'No messages sent yet',
                subtitle: 'Messages will appear here after the rule fires.',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  return GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: sent at + delete
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.green),
                            const SizedBox(width: 6),
                            Text(
                              AppDateUtils.formatSentAt(msg.sentAt),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => ref
                                  .read(ruleMessagesProvider(ruleId).notifier)
                                  .deleteMessage(ruleId, msg.id),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Message content
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border.fromBorderSide(
                                BorderSide(color: AppColors.border)),
                          ),
                          child: Text(
                            msg.content,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),

                        if (msg.noteUsed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.notes,
                                  size: 13, color: AppColors.textDim),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Note: ${msg.noteUsed}',
                                  style: const TextStyle(
                                    color: AppColors.textDim,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
