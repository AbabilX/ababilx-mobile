import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/friendly_error.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_connection.dart';

class ChatConnectionsState {
  const ChatConnectionsState({
    this.connections = const [],
    this.requests = const [],
    this.sent = const [],
    this.searchResults = const [],
    this.loading = false,
    this.searching = false,
    this.error = '',
  });

  final List<ChatConnection> connections;
  final List<ChatConnection> requests;
  final List<ChatConnection> sent;
  final List<ChatUserSummary> searchResults;
  final bool loading;
  final bool searching;
  final String error;

  ChatConnectionsState copyWith({
    List<ChatConnection>? connections,
    List<ChatConnection>? requests,
    List<ChatConnection>? sent,
    List<ChatUserSummary>? searchResults,
    bool? loading,
    bool? searching,
    String? error,
  }) => ChatConnectionsState(
    connections: connections ?? this.connections,
    requests: requests ?? this.requests,
    sent: sent ?? this.sent,
    searchResults: searchResults ?? this.searchResults,
    loading: loading ?? this.loading,
    searching: searching ?? this.searching,
    error: error ?? this.error,
  );
}

class ChatConnectionsNotifier extends Notifier<ChatConnectionsState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  ChatConnectionsState build() => const ChatConnectionsState();

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: '');
    try {
      final results = await Future.wait([
        _repo.listConnections(),
        _repo.listConnectionRequests(),
      ]);
      final requests = results[1] as ChatConnectionRequests;
      state = state.copyWith(
        connections: results[0] as List<ChatConnection>,
        requests: requests.incoming,
        sent: requests.sent,
        loading: false,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> search(String query) async {
    final value = query.trim();
    if (value.length < 3) {
      state = state.copyWith(
        searchResults: const [],
        searching: false,
        error: '',
      );
      return;
    }
    state = state.copyWith(searching: true, error: '');
    try {
      final result = await _repo.searchUsers(value);
      state = state.copyWith(searchResults: result.users, searching: false);
    } catch (error) {
      // A refusal the server explained in words — "add the country code to
      // search by phone" — is worth far more than "Something went wrong",
      // which is what friendlyErrorMessage collapses every 400 into.
      state = state.copyWith(
        searching: false,
        searchResults: const [],
        error: serverErrorMessage(error) ?? friendlyErrorMessage(error),
      );
    }
  }

  Future<void> sendRequest(String userId) async {
    await _repo.sendConnectionRequest(userId);
    await refresh();
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    await _repo.respondConnectionRequest(requestId, accept: accept);
    await refresh();
  }

  Future<void> block(String userId) async {
    await _repo.blockUser(userId);
    await refresh();
  }

  Future<void> remove(String userId) async {
    await _repo.removeConnection(userId);
    await refresh();
  }
}

final chatConnectionsProvider =
    NotifierProvider<ChatConnectionsNotifier, ChatConnectionsState>(
      ChatConnectionsNotifier.new,
    );
