import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart';
import '../providers/rules_provider.dart';
import '../../../core/localization/app_translations.dart';

class RuleHistoryScreen extends ConsumerWidget {
  const RuleHistoryScreen({super.key, required this.ruleId});
  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(ruleMessagesProvider(ruleId));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppTranslations.translate(context, ref, 'msg_history'),
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
      body: messagesAsync.when(
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(Icons.error_outline_rounded,
                    color: colors.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                e.toString(),
                style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14),
              ),
            ],
          ),
        ),
        data: (messages) => messages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
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
                        child: Icon(
                          Icons.history_rounded,
                          size: 36,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppTranslations.translate(context, ref, 'no_messages'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.translate(context, ref, 'no_messages_desc'),
                        style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.outline,
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: flat solid status pill + datetime + squircle delete button tile
                        Row(
                          children: [
                            // Symmetrical flat solid green success pill capsule
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF142F1C),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: const Color(0xFF22C55E),
                                    width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 14, color: Color(0xFF22C55E)),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppTranslations.translate(context, ref, 'sent'),
                                    style: const TextStyle(
                                      color: Color(0xFF22C55E),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                AppDateUtils.formatSentAt(msg.sentAt),
                                style: const TextStyle(
                                  color: Color(0xFFCAC4D0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Mini symmetrical red tonal squircle delete button tile
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E1B1B),
                                  foregroundColor: const Color(0xFFF2B8B5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: Color(0xFF601410), width: 0.8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                onPressed: () => ref
                                    .read(ruleMessagesProvider(ruleId).notifier)
                                    .deleteMessage(ruleId, msg.id),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Solid flat inner message card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.outline,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            msg.content,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),

                        if (msg.noteUsed.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.psychology_outlined,
                                  size: 16, color: Color(0xFFCAC4D0)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note: ${msg.noteUsed}',
                                  style: const TextStyle(
                                    color: Color(0xFFCAC4D0),
                                    fontSize: 12,
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
                  );
                },
              ),
      ),
    );
  }
}
