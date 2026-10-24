import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/profile_provider.dart';
import 'icon_avatar_choices.dart';
import 'icon_avatar_picker.dart';
import 'profile_setup_step.dart';

/// Step 4: the profile picture.
///
/// The choice lives on this step until Next. With no picture yet, the first
/// Hugeicons tile is selected in state (never null, never uploaded on open).
/// Tapping another icon or picking from the gallery only replaces that
/// state. Next writes once — or writes nothing when a picture is already
/// on the account and nothing here changed.
class PhotoStep extends ConsumerStatefulWidget {
  const PhotoStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends ConsumerState<PhotoStep> {
  bool _saving = false;
  bool _failed = false;
  final _icons = GlobalKey<IconAvatarPickerState>();

  /// Selected tile. Set to the default when the account has no picture.
  /// Stays null while an existing picture is kept as-is.
  int? _iconIndex;

  /// Cropped gallery bytes. Wins over [_iconIndex] until another icon is tapped.
  Uint8List? _gallery;

  @override
  void initState() {
    super.initState();
    final url = ref.read(profileProvider).valueOrNull?.avatarUrl ?? '';
    if (url.isEmpty) _iconIndex = iconAvatarDefaultIndex;
  }

  Future<void> _pick() async {
    final bytes = await pickImageBytes(context);
    if (bytes == null || !mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => ImageCropEditor(bytes: bytes)),
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _gallery = cropped;
      _failed = false;
    });
  }

  Future<bool> _save(Uint8List bytes) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(profileProvider.notifier).updateAvatar(bytes);
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
      return false;
    }
  }

  Future<void> _next() async {
    final gallery = _gallery;
    if (gallery != null) {
      if (await _save(gallery) && mounted) widget.onDone();
      return;
    }
    if (_iconIndex == null) {
      widget.onDone();
      return;
    }
    final jpeg = await _icons.currentState?.renderSelected();
    if (!mounted) return;
    if (jpeg == null) {
      setState(() => _failed = true);
      return;
    }
    if (await _save(jpeg) && mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ref.watch(profileProvider).valueOrNull;
    final hasPhoto = (user?.avatarUrl ?? '').isNotEmpty;
    final hasChoice = _gallery != null || _iconIndex != null || hasPhoto;
    return ProfileSetupStep(
      step: 2,
      titleKey: 'profile_setup_photo_title',
      bodyKey: 'profile_setup_photo_body',
      busy: _saving,
      onNext: hasChoice && !_saving ? _next : null,
      // Full width, so the picture and the icons sit on the screen's centre
      // line rather than on the widest child's.
      field: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            GestureDetector(
              onTap: _saving ? null : _pick,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _Preview(
                    gallery: _gallery,
                    iconIndex: _gallery == null ? _iconIndex : null,
                    url: user?.avatarUrl,
                    name: user?.name,
                    owner: user == null ? null : 'user:${user.id}',
                  ),
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 3),
                      ),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera01,
                          size: 18,
                          color: colors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _saving ? null : _pick,
              child: Text(
                t(
                  hasPhoto || _gallery != null
                      ? 'profile_setup_photo_change'
                      : 'profile_setup_photo_choose',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('profile_setup_photo_icons'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            IconAvatarPicker(
              key: _icons,
              enabled: !_saving,
              // A gallery photo is the choice; the ring comes back when an
              // icon is tapped again.
              selected: _gallery == null ? _iconIndex : null,
              onSelect: (index) {
                setState(() {
                  _iconIndex = index;
                  _gallery = null;
                  _failed = false;
                });
              },
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t('profile_setup_photo_error'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.gallery,
    required this.iconIndex,
    required this.url,
    required this.name,
    required this.owner,
  });

  final Uint8List? gallery;
  final int? iconIndex;
  final String? url;
  final String? name;
  final String? owner;

  static const double _size = 128;

  @override
  Widget build(BuildContext context) {
    final gallery = this.gallery;
    if (gallery != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppAvatar.radius),
        child: Image.memory(
          gallery,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
        ),
      );
    }
    final index = iconIndex;
    if (index != null) {
      final choice = iconAvatarChoices[index];
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppAvatar.radius),
        child: ColoredBox(
          color: choice.background,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Center(
              child: HugeIcon(
                icon: choice.icon,
                size: _size * 0.5,
                color: choice.ink,
              ),
            ),
          ),
        ),
      );
    }
    return AppAvatar(size: _size, url: url, name: name, owner: owner);
  }
}
