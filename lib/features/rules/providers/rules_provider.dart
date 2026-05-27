import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/rule.dart';
import '../data/models/rule_message.dart';
import '../data/rules_repository.dart';

// ---------------------------------------------------------------------------
// Rules list
// ---------------------------------------------------------------------------

class RulesNotifier extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() => _fetch();

  Future<List<Rule>> _fetch() =>
      ref.read(rulesRepositoryProvider).getRules();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> toggleRule(String id, bool isActive) async {
    final repo = ref.read(rulesRepositoryProvider);
    final rules = state.valueOrNull ?? [];
    final idx = rules.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    // Optimistic update
    final updated = rules[idx].copyWith(isActive: isActive);
    state = AsyncData([...rules]..[idx] = updated);

    try {
      await repo.updateRule(id, updated.toJson());
    } catch (_) {
      // Revert
      state = AsyncData([...rules]..[idx] = rules[idx]);
      rethrow;
    }
  }

  Future<void> deleteRule(String id) async {
    await ref.read(rulesRepositoryProvider).deleteRule(id);
    final rules = state.valueOrNull ?? [];
    state = AsyncData(rules.where((r) => r.id != id).toList());
  }

  Future<void> triggerRule(String id) async {
    await ref.read(rulesRepositoryProvider).triggerRule(id);
  }

  void addRule(Rule rule) {
    final rules = state.valueOrNull ?? [];
    state = AsyncData([rule, ...rules]);
  }

  void updateRuleLocally(Rule rule) {
    final rules = state.valueOrNull ?? [];
    final idx = rules.indexWhere((r) => r.id == rule.id);
    if (idx == -1) {
      state = AsyncData([rule, ...rules]);
    } else {
      state = AsyncData([...rules]..[idx] = rule);
    }
  }
}

final rulesProvider =
    AsyncNotifierProvider<RulesNotifier, List<Rule>>(RulesNotifier.new);

// ---------------------------------------------------------------------------
// Rule messages (history)
// ---------------------------------------------------------------------------

class RuleMessagesNotifier
    extends FamilyAsyncNotifier<List<RuleMessage>, String> {
  @override
  Future<List<RuleMessage>> build(String ruleId) =>
      ref.read(rulesRepositoryProvider).getRuleMessages(ruleId);

  Future<void> deleteMessage(String ruleId, String msgId) async {
    await ref.read(rulesRepositoryProvider).deleteRuleMessage(ruleId, msgId);
    final msgs = state.valueOrNull ?? [];
    state = AsyncData(msgs.where((m) => m.id != msgId).toList());
  }
}

final ruleMessagesProvider =
    AsyncNotifierProviderFamily<RuleMessagesNotifier, List<RuleMessage>, String>(
  RuleMessagesNotifier.new,
);

// ---------------------------------------------------------------------------
// Rule preview (AI-generated message before send)
// ---------------------------------------------------------------------------

class RulePreviewNotifier extends FamilyAsyncNotifier<String?, String> {
  @override
  Future<String?> build(String ruleId) async => null; // lazy, not auto-fetched

  Future<void> generate(String ruleId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(rulesRepositoryProvider).previewRule(ruleId),
    );
  }

  Future<void> triggerWithMessage(String ruleId, String message) async {
    await ref.read(rulesRepositoryProvider).triggerRule(ruleId, message: message);
  }

  Future<void> saveOverride(String ruleId, String content) async {
    await ref.read(rulesRepositoryProvider).overrideMessage(ruleId, content);
  }
}

final rulePreviewProvider =
    AsyncNotifierProviderFamily<RulePreviewNotifier, String?, String>(
  RulePreviewNotifier.new,
);

// ---------------------------------------------------------------------------
// Slack channels (for rule form)
// ---------------------------------------------------------------------------

final slackChannelsProvider = FutureProvider(
  (ref) => ref.read(rulesRepositoryProvider).getSlackChannels(),
);
