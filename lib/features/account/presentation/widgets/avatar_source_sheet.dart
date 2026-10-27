import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/account/data/avatar_picker.dart';
import 'package:oxro/features/account/data/profile_store.dart';

enum _AvatarAction { camera, gallery, remove }

/// Bottom sheet: Camera / Gallery, plus Remove when a photo exists.
/// Picks, saves and reports the outcome — callers need no extra logic.
Future<void> showAvatarSourceSheet(
  BuildContext context, {
  required bool hasPhoto,
}) async {
  final action = await showModalBottomSheet<_AvatarAction>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('avatar_sheet'),
        padding: EdgeInsets.fromLTRB(
          context.padX,
          0,
          context.padX,
          context.rs(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile photo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: OxroColors.charcoal,
              ),
            ),
            SizedBox(height: context.rs(4)),
            const Text(
              'Choose a clear photo so riders can recognise you.',
              style: TextStyle(fontSize: 12, color: OxroColors.muted),
            ),
            SizedBox(height: context.rs(14)),
            _SheetTile(
              tileKey: const ValueKey('avatar_camera'),
              icon: Icons.photo_camera_rounded,
              label: 'Take a photo',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AvatarAction.camera),
            ),
            SizedBox(height: context.rs(8)),
            _SheetTile(
              tileKey: const ValueKey('avatar_gallery'),
              icon: Icons.photo_library_rounded,
              label: 'Choose from gallery',
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AvatarAction.gallery),
            ),
            if (hasPhoto) ...[
              SizedBox(height: context.rs(8)),
              _SheetTile(
                tileKey: const ValueKey('avatar_remove'),
                icon: Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: OxroColors.red,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarAction.remove),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (action == null) return;

  if (action == _AvatarAction.remove) {
    await ProfileStore.instance.clearAvatar();
    if (!context.mounted) return;
    showOxroSnack(context, 'Profile photo removed');
    return;
  }

  try {
    final bytes = await AvatarPicker.instance.pick(
      action == _AvatarAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (bytes == null) return;
    final err = await ProfileStore.instance.setAvatar(bytes);
    if (!context.mounted) return;
    showOxroSnack(context, err ?? 'Profile photo updated');
  } catch (_) {
    if (!context.mounted) return;
    showOxroSnack(context, "Couldn't open photos. Try again.");
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = OxroColors.primary,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.rs(12),
            vertical: context.rs(12),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              SizedBox(width: context.rs(10)),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OxroColors.charcoal,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: OxroColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
