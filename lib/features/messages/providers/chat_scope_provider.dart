import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatScopeFilter { all, personal, workspaces }

final chatScopeProvider = StateProvider<ChatScopeFilter>(
  (ref) => ChatScopeFilter.all,
);
