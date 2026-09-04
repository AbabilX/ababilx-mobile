import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/media/media_quality.dart';

/// Settings → Media quality. Signal's "Sent media quality": how hard a picture
/// is squeezed before it is sent.
///
/// The same two options sit in the review screen's own sheet, and both write
/// the one remembered setting. This screen exists so it can be found without
/// opening a picker first.
class MediaQualityScreen extends ConsumerWidget {
  const MediaQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(mediaQualityProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Media quality')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _MediaQualityTile(
            quality: MediaQuality.standard,
            current: current,
            title: 'Standard',
            subtitle: 'Faster, less data',
          ),
          _MediaQualityTile(
            quality: MediaQuality.high,
            current: current,
            title: 'High',
            subtitle: 'Slower, more data',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Applies to photos you send. Videos are sent as they are.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaQualityTile extends ConsumerWidget {
  const _MediaQualityTile({
    required this.quality,
    required this.current,
    required this.title,
    required this.subtitle,
  });

  final MediaQuality quality;
  final MediaQuality current;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final selected = quality == current;

    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_rounded, color: colors.primary)
          : null,
      selected: selected,
      onTap: () => ref.read(mediaQualityProvider.notifier).set(quality),
    );
  }
}
