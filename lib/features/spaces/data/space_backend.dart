import 'space_message.dart';
import 'space_models.dart';

/// What the screens need from `/api/spaces`; `SpaceApi` in the app, a fake
/// in tests.
abstract class SpacesBackend {
  Future<List<SpaceSummary>> listSpaces();
  Future<SpaceTree> channels(String spaceId);
  Future<SpaceSummary> createSpace(String name);
  Future<SpaceSummary> joinInvite(String code);
  Future<List<SpaceMessage>> messages(
    String spaceId,
    String channelId, {
    String? before,
  });
  Future<SpaceMessage> send(
    String spaceId,
    String channelId,
    String body, {
    required String clientId,
  });
}
