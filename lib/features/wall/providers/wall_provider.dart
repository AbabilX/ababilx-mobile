import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';
import '../data/models/wall_models.dart';
import '../data/wall_repository.dart';
import 'wall_state.dart';

part 'wall_provider_feed.dart';
part 'wall_provider_mutate.dart';

class WallNotifier extends Notifier<WallState>
    with _WallFeedMixin, _WallMutateMixin {
  @override
  WallRepository get repo => ref.read(wallRepositoryProvider);

  @override
  WallState build() => const WallState();

  Future<void> bootstrap() async {
    final profile = await ref.read(profileProvider.future);
    state = state.copyWith(currentUserId: profile.id);
    await Future.wait([loadInitial(), refreshMeta()]);
  }
}

final wallProvider = NotifierProvider<WallNotifier, WallState>(
  WallNotifier.new,
);

final wallPostProvider = FutureProvider.family<WallPost, String>((
  ref,
  postId,
) async {
  return ref.watch(wallRepositoryProvider).getPost(postId);
});
