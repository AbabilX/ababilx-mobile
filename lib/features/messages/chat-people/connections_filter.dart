import '../data/models/chat_connection.dart';

/// Client-side filter for the connections list (name + @username).
List<ChatConnection> filterConnections(
  List<ChatConnection> connections,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return connections;

  return connections.where((connection) {
    final user = connection.user;
    if (user.name.toLowerCase().contains(q)) return true;
    final username = user.username.toLowerCase();
    if (username.isEmpty) return false;
    if (username.contains(q)) return true;
    return '@$username'.contains(q);
  }).toList();
}
