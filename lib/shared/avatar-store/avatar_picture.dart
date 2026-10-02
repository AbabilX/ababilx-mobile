import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'avatar_store.dart';

/// A profile or group picture drawn from the phone's own copy.
///
/// The file is found synchronously ([AvatarStore.fileFor]), so a picture the
/// phone holds is on screen in the first frame that can decode it — and in the
/// very first frame when [warmAvatarFiles] decoded it ahead of time. Nothing
/// is asked of the network here; a missing picture shows [placeholder] while
/// the store fetches it, then swaps in.
class AvatarPicture extends StatefulWidget {
  const AvatarPicture({
    super.key,
    required this.url,
    required this.placeholder,
    this.owner,
  });

  final String url;

  /// `user:<id>` / `conv:<id>`: lets a changed photo keep showing the old one
  /// until the new one is on disk.
  final String? owner;
  final Widget placeholder;

  /// The provider every avatar file is drawn through. Warm-up resolves the
  /// same one, so the image cache answers the first build synchronously.
  static ImageProvider imageFor(File file) => FileImage(file);

  @override
  State<AvatarPicture> createState() => _AvatarPictureState();
}

class _AvatarPictureState extends State<AvatarPicture> {
  final _store = AvatarStore.instance;
  List<Listenable> _watched = const [];

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(AvatarPicture old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.owner != widget.owner) _watch();
  }

  @override
  void dispose() {
    for (final l in _watched) {
      l.removeListener(_changed);
    }
    super.dispose();
  }

  void _watch() {
    for (final l in _watched) {
      l.removeListener(_changed);
    }
    final url = AvatarStore.normalize(widget.url);
    _watched = [
      if (url != null) _store.changes(url),
      if (widget.owner != null) _store.changes(widget.owner!),
    ];
    for (final l in _watched) {
      l.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final file = _store.fileFor(widget.url, owner: widget.owner);
    if (file == null) return widget.placeholder;
    return Image(
      image: AvatarPicture.imageFor(file),
      fit: BoxFit.cover,
      // A swap to a new photo keeps the old one up until the new one decodes.
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if (sync || frame != null) return child;
        // Still decoding: the letter below, and over it the previous photo
        // when this is a swap (gapless keeps it in [child]).
        return Stack(
          fit: StackFit.expand,
          children: [widget.placeholder, child],
        );
      },
      errorBuilder: (_, _, _) {
        // Not during build: forgetting notifies listeners, this one included.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _store.forget(file),
        );
        return widget.placeholder;
      },
    );
  }
}

/// Decodes the pictures behind [urls] into Flutter's image cache, so the
/// widgets that draw them paint with the picture in their first frame instead
/// of the letter. Returns once all are decoded or [timeout] passes.
Future<void> warmAvatarFiles(
  Iterable<({String url, String? owner})> refs, {
  Duration timeout = const Duration(milliseconds: 350),
}) async {
  final store = AvatarStore.instance;
  final pending = <Future<void>>[];
  for (final ref in refs) {
    final file = store.fileFor(ref.url, owner: ref.owner);
    if (file == null) continue;
    pending.add(_decode(AvatarPicture.imageFor(file)));
  }
  if (pending.isEmpty) return;
  await Future.wait(pending).timeout(timeout, onTimeout: () => const []);
}

Future<void> _decode(ImageProvider provider) {
  final done = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future;
}
