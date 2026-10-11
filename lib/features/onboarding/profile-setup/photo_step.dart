import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/localization/app_translations.dart';
import '../../../shared/media/image_crop_editor.dart';
import '../../../shared/media/pick_image_bytes.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../profile/providers/profile_provider.dart';
import 'profile_setup_step.dart';

/// Step 4: the profile picture. Optional — a Google account usually arrives
/// with one, and Settings changes it later. Same pick → crop → upload path
/// as Settings.
class PhotoStep extends ConsumerStatefulWidget {
  const PhotoStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends ConsumerState<PhotoStep> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _pick() async {
    final bytes = await pickImageBytes(context);
    if (bytes == null || !mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => ImageCropEditor(bytes: bytes)),
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(profileProvider.notifier).updateAvatar(cropped);
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppTranslations.translate(context, ref, key);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ref.watch(profileProvider).valueOrNull;
    final hasPhoto = (user?.avatarUrl ?? '').isNotEmpty;
    return ProfileSetupStep(
      step: 3,
      titleKey: 'profile_setup_photo_title',
      bodyKey: 'profile_setup_photo_body',
      busy: _saving,
      onNext: hasPhoto ? widget.onDone : null,
      onSkip: hasPhoto ? null : widget.onDone,
      field: Column(
        children: [
          GestureDetector(
            onTap: _saving ? null : _pick,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AppAvatar(
                  size: 128,
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
                hasPhoto
                    ? 'profile_setup_photo_change'
                    : 'profile_setup_photo_choose',
              ),
            ),
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
    );
  }
}
