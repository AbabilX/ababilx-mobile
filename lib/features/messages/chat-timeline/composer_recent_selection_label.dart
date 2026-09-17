/// Copy for the composer chip that remembers Recents picks after the
/// attachment keyboard closes (user tapped the text field to type a caption).
///
/// Pure so the wording can be pinned without pumping a widget.
String recentSelectionBadgeLabel({
  required int photoCount,
  required int videoCount,
  required bool bengali,
}) {
  final photos = photoCount < 0 ? 0 : photoCount;
  final videos = videoCount < 0 ? 0 : videoCount;
  final total = photos + videos;
  if (total == 0) return '';

  if (bengali) {
    if (videos == 0) {
      return photos == 1 ? '১টি ছবি যোগ হয়েছে' : '$photosটি ছবি যোগ হয়েছে';
    }
    if (photos == 0) {
      return videos == 1
          ? '১টি ভিডিও যোগ হয়েছে'
          : '$videosটি ভিডিও যোগ হয়েছে';
    }
    return '$totalটি আইটেম যোগ হয়েছে';
  }

  if (videos == 0) {
    return photos == 1 ? '1 image added' : '$photos images added';
  }
  if (photos == 0) {
    return videos == 1 ? '1 video added' : '$videos videos added';
  }
  return '$total items added';
}
