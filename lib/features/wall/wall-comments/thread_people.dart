import '../data/models/wall_models.dart';

class WallThreadPerson {
  const WallThreadPerson(this.name, this.avatarUrl);
  final String? name;
  final String? avatarUrl;
}

List<WallThreadPerson> wallThreadParticipants(
  WallComment root,
  List<WallComment> replies, {
  int max = 3,
}) {
  final byUser = <String, ({WallThreadPerson p, int ts})>{};
  void consider(WallComment c) {
    final ts = DateTime.tryParse(c.createdAt)?.millisecondsSinceEpoch ?? 0;
    final ex = byUser[c.userId];
    if (ex == null || ts > ex.ts) {
      byUser[c.userId] = (
        p: WallThreadPerson(c.userName, c.userAvatarUrl),
        ts: ts,
      );
    }
  }

  for (final r in replies) {
    consider(r);
  }
  if (byUser.isEmpty) consider(root);
  final ranked = byUser.values.toList()
    ..sort((a, b) => b.ts.compareTo(a.ts));
  return ranked.take(max).map((e) => e.p).toList();
}

WallComment wallLatestReply(List<WallComment> replies) {
  var latest = replies.first;
  var latestTs =
      DateTime.tryParse(latest.createdAt)?.millisecondsSinceEpoch ?? 0;
  for (final r in replies.skip(1)) {
    final ts = DateTime.tryParse(r.createdAt)?.millisecondsSinceEpoch ?? 0;
    if (ts > latestTs) {
      latest = r;
      latestTs = ts;
    }
  }
  return latest;
}
