import '../../../shared/media/device_gallery.dart';

List<DeviceMediaItem> toggleRecentSelection(
  List<DeviceMediaItem> current,
  DeviceMediaItem item,
) {
  if (current.contains(item)) {
    return current.where((candidate) => candidate != item).toList();
  }
  return [...current, item];
}
