import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Message History',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        leading: const BackButton(),
      ),
      body: messagesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.indigo, strokeWidth: 2.5)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.textMuted, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        data: (messages) => messages.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'No messages sent yet',
                subtitle: 'Messages will appear here after the rule fires.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
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
                        color: AppColors.border,
                        width: 1.2,
                      ),
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
                          // Left dynamic success green accent strip (clipped)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 6,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),

                          // Card content
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: sent at + delete
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16, color: AppColors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppDateUtils.formatSentAt(msg.sentAt),
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Mini squircle delete button tile
                                    Material(
                                      color: AppColors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        onTap: () => ref
                                            .read(ruleMessagesProvider(ruleId).notifier)
                                            .deleteMessage(ruleId, msg.id),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: AppColors.red.withOpacity(0.12),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16,
                                            color: AppColors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Translucent glassmorphic inner message bubble
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.04),
                                      width: 0.8,
                                    ),
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(Icons.notes_rounded,
                                          size: 14, color: AppColors.textDim),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Note: ${msg.noteUsed}',
                                          style: const TextStyle(
                                            color: AppColors.textDim,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
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
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
