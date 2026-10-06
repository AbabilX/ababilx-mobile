import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../ghost/protocol/ghost_item_rules.dart';
import '../ghost/widgets/ghost_labels.dart';
import '../messages/chat_icon.dart';
import '../messages/data/chat_repository.dart';
import '../messages/data/models/chat_models.dart';
import '../../shared/widgets/app_toast.dart';
import 'privacy_secure_scope.dart';
import 'privacy_timed_sealed.dart';

/// What this phone did with each timed photo this session.
///
/// [shown]: the picture reached the screen — never again, which is what
/// "view once" means. [retry]: the server clock started but the download
/// failed; the card stays tappable, because the server still hands the URL
/// out until the photo expires and the person never saw it.
class TimedMediaLocal {
  const TimedMediaLocal({this.shown = const {}, this.retry = const {}});

  final Set<String> shown;
  final Set<String> retry;
}

final openedTimedMediaProvider =
    NotifierProvider<OpenedTimedMedia, TimedMediaLocal>(OpenedTimedMedia.new);

class OpenedTimedMedia extends Notifier<TimedMediaLocal> {
  @override
  TimedMediaLocal build() => const TimedMediaLocal();

  void shown(String id) => state = TimedMediaLocal(
    shown: {...state.shown, id},
    retry: {...state.retry}..remove(id),
  );

  void failed(String id) =>
      state = TimedMediaLocal(shown: state.shown, retry: {...state.retry, id});
}

/// A timed photo is at most this big; anything larger is refused rather than
/// held in memory.
const _maxTimedBytes = 50 * 1024 * 1024;

/// Opens a timed photo on the receiving phone.
///
/// `POST .../viewed` starts the server clock and is the only thing that hands
/// out the photo's URL (every other read withholds it). The bytes go straight
/// into memory with a bare client — the CDN never sees the JWT, and nothing is
/// written to disk, so there is no file to forget to delete if the app dies
/// mid-view. They are zeroed when the viewer closes.
///
/// Offline, it does not open: a photo opened without the server knowing would
/// never expire for its sender.
Future<void> openTimedPhoto(
  BuildContext context,
  WidgetRef ref,
  ChatMessageAttachment attachment,
) async {
  final failed = ghostText(ref, 'ghost_err_generic');
  Uint8List? bytes;
  try {
    final grants = await ref
        .read(chatRepositoryProvider)
        .markMediaViewed(attachment.messageId);
    final grant = grants[attachment.id];
    final url = grant?.url;
    if (grant != null && url != null && url.startsWith('https://')) {
      final res = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = res.data;
      if (data != null && data.isNotEmpty && data.length <= _maxTimedBytes) {
        final raw = Uint8List.fromList(data);
        // An encrypted photo (server 0168) arrives as ciphertext, and its
        // key came with the URL: opened here, in memory.
        bytes = grant.isSealed
            ? await openSealedTimedPhoto(ref, attachment, grant, raw)
            : raw;
      }
    }
  } catch (_) {}
  final local = ref.read(openedTimedMediaProvider.notifier);
  if (bytes == null) {
    local.failed(attachment.id);
    if (context.mounted) showAppToast(context, failed, isError: true);
    return;
  }
  local.shown(attachment.id);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _TimedPhotoViewer(
        bytes: bytes!,
        timer: GhostViewTimer.decode(
          attachment.viewSeconds == 0 ? 'once' : attachment.viewSeconds,
        ),
      ),
    ),
  );
  bytes.fillRange(0, bytes.length, 0);
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

class _TimedPhotoViewer extends ConsumerStatefulWidget {
  const _TimedPhotoViewer({required this.bytes, required this.timer});

  final Uint8List bytes;
  final GhostViewTimer timer;

  @override
  ConsumerState<_TimedPhotoViewer> createState() => _TimedPhotoViewerState();
}

class _TimedPhotoViewerState extends ConsumerState<_TimedPhotoViewer> {
  Timer? _deadline;
  Timer? _tick;
  late final DateTime _ends;

  @override
  void initState() {
    super.initState();
    // Wall clock, not an animation: animations pause in the background, and
    // a photo must not wait out its timer behind the home screen.
    final duration = widget.timer.duration;
    _ends = DateTime.now().add(duration ?? Duration.zero);
    if (duration != null) {
      _deadline = Timer(duration, () {
        if (mounted) Navigator.of(context).maybePop();
      });
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _ends.difference(DateTime.now());
    final label = widget.timer.duration == null
        ? ghostTimerLabel(ref, widget.timer)
        : '${(left.inMilliseconds / 1000).ceil().clamp(0, 99)}s';
    return PrivacySecureScope(
      active: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const ChatIcon(
              HugeIcons.strokeRoundedCancel01,
              color: Colors.white,
            ),
          ),
          actions: [
            Center(
              child: Text(label, style: const TextStyle(color: Colors.white70)),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(widget.bytes, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }
}
