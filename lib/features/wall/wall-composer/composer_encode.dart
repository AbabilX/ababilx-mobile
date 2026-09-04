import '../../messages/tiptap_encode.dart';
import '../data/models/wall_models.dart';

/// Builds TipTap JSON with `mention` + optional `wallCategory` nodes (web parity).
///
/// The walk itself lives in [encodeTiptapBody], shared with the chat composer:
/// the wall and a chat message differ only in that the wall can also carry one
/// category tag, and two copies of a mention parser drift.
String encodeWallBody({
  required String plain,
  required Map<String, String> mentionByLabel,
  WallCategory? category,
}) => encodeTiptapBody(
  plain: plain,
  mentionByLabel: mentionByLabel,
  tagLabel: category?.label,
  tagId: category?.slug,
);
