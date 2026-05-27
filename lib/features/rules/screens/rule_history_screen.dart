import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart';
import '../providers/rules_provider.dart';
import '../data/models/rule.dart';
import '../../../core/localization/app_translations.dart';

class RuleHistoryScreen extends ConsumerStatefulWidget {
  const RuleHistoryScreen({super.key, required this.ruleId});
  final String ruleId;

  @override
  ConsumerState<RuleHistoryScreen> createState() => _RuleHistoryScreenState();
}

class _RuleHistoryScreenState extends ConsumerState<RuleHistoryScreen> {
  final _noteCtrl = TextEditingController();
  bool _noteSaving = false;
  bool _noteSaved = false;

  String? _editingId;
  final _editCtrl = TextEditingController();
  bool _editSaving = false;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNote());
  }

  void _initNote() {
    final rules = ref.read(rulesProvider).valueOrNull ?? [];
    final rule = _findRule(rules);
    if (rule != null) _noteCtrl.text = rule.note;
  }

  Rule? _findRule(List<Rule> rules) {
    try {
      return rules.firstWhere((r) => r.id == widget.ruleId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    setState(() { _noteSaving = true; _noteSaved = false; });
    try {
      await ref.read(rulesProvider.notifier).updateNote(widget.ruleId, _noteCtrl.text);
      if (mounted) setState(() => _noteSaved = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _noteSaving = false);
    }
  }

  Future<void> _sendNow() async {
    setState(() => _sending = true);
    try {
      await ref.read(rulesProvider.notifier).triggerRule(widget.ruleId);
      if (mounted) {
        _noteCtrl.clear();
        ref.invalidate(ruleMessagesProvider(widget.ruleId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Message sent!'),
            ]),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startEdit(String id, String content) {
    _editCtrl.text = content;
    setState(() { _editingId = id; _editSaving = false; });
  }

  Future<void> _saveEdit(String msgId) async {
    if (_editCtrl.text.trim().isEmpty) return;
    setState(() => _editSaving = true);
    try {
      await ref.read(ruleMessagesProvider(widget.ruleId).notifier)
          .updateMessage(widget.ruleId, msgId, _editCtrl.text.trim());
      if (mounted) setState(() => _editingId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _editSaving = false);
    }
  }

  void _confirmDelete(BuildContext context) {
    final rules = ref.read(rulesProvider).valueOrNull ?? [];
    final rule = _findRule(rules);
    showDialog(
      context: context,
      builder: (dlg) => Dialog(
        backgroundColor: const Color(0xFF211F26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFF35343B)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF601410),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF2B8B5), size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Delete Rule',
                  style: TextStyle(color: Color(0xFFE6E1E5), fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Delete "${rule?.name ?? ''}"?\nThis cannot be undone.',
                  style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dlg),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFCAC4D0),
                        side: const BorderSide(color: Color(0xFF35343B)),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dlg);
                        ref.read(rulesProvider.notifier).deleteRule(widget.ruleId);
                        context.go('/rules');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF601410),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(ruleMessagesProvider(widget.ruleId));
    final rules = ref.watch(rulesProvider).valueOrNull ?? [];
    final rule = _findRule(rules);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (rule?.name.isNotEmpty ?? false) ? rule!.name : AppTranslations.translate(context, ref, 'msg_history'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if ((rule?.channelName.isNotEmpty ?? false))
              Text(
                '#${rule!.channelName}',
                style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 12, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/rules'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Edit rule',
            onPressed: () => context.go('/rules/${widget.ruleId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFF2B8B5)),
            tooltip: 'Delete rule',
            onPressed: () => _confirmDelete(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // ── AI Context Note ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_outlined, size: 18, color: colors.primary),
                    const SizedBox(width: 10),
                    const Text(
                      'AI Context Note',
                      style: TextStyle(color: Color(0xFFE6E1E5), fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Extra context for AI — meetings, blockers, decisions. Cleared after each send.',
                  style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  onChanged: (_) => setState(() => _noteSaved = false),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Had planning meeting, reviewed 3 PRs, blocked on auth service',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_noteSaving)
                      const Text('Saving…', style: TextStyle(color: Color(0xFFCAC4D0), fontSize: 12))
                    else if (_noteSaved)
                      const Row(children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text('Saved', style: TextStyle(color: Color(0xFF22C55E), fontSize: 12)),
                      ]),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: _noteSaving ? null : _saveNote,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save draft', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Message history header ───────────────────────────────────────
          Row(
            children: [
              Text(
                AppTranslations.translate(context, ref, 'msg_history'),
                style: const TextStyle(color: Color(0xFFE6E1E5), fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8DEF8)),
                    )
                  : FilledButton.icon(
                      onPressed: _sendNow,
                      icon: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text('Send Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF381E72),
                        foregroundColor: const Color(0xFFE8DEF8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Messages list ────────────────────────────────────────────────
          messagesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: Color(0xFFCAC4D0), fontSize: 14)),
            ),
            data: (messages) => messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
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
                            child: Icon(Icons.history_rounded, size: 32, color: colors.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppTranslations.translate(context, ref, 'no_messages'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                : Column(
                    children: messages.map((msg) {
                      final isEditing = _editingId == msg.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: colors.outline, width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF142F1C),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
                                      SizedBox(width: 4),
                                      Text('Sent',
                                          style: TextStyle(
                                              color: Color(0xFF22C55E),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppDateUtils.formatSentAt(msg.sentAt),
                                    style: const TextStyle(
                                        color: Color(0xFFCAC4D0), fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isEditing) ...[
                                  IconButton(
                                    icon: _editSaving
                                        ? const SizedBox(
                                            width: 16, height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF22C55E)))
                                        : const Icon(Icons.check_rounded, size: 18, color: Color(0xFF22C55E)),
                                    onPressed: _editSaving ? null : () => _saveEdit(msg.id),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFCAC4D0)),
                                    onPressed: () => setState(() => _editingId = null),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFCAC4D0)),
                                    onPressed: () => _startEdit(msg.id, msg.content),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      style: IconButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E1B1B),
                                        foregroundColor: const Color(0xFFF2B8B5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: const BorderSide(color: Color(0xFF601410), width: 0.8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                      onPressed: () => ref
                                          .read(ruleMessagesProvider(widget.ruleId).notifier)
                                          .deleteMessage(widget.ruleId, msg.id),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Content
                            if (isEditing)
                              TextField(
                                controller: _editCtrl,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: colors.surfaceContainer,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: colors.primary),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                                style: const TextStyle(fontSize: 13, height: 1.5),
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.outline, width: 1.0),
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                      color: colors.onSurface, fontSize: 14, height: 1.5),
                                ),
                              ),

                            // Note used
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
                                          fontWeight: FontWeight.w500),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
