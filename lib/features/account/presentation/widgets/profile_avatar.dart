import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/features/account/data/profile_store.dart';

/// Circular profile photo with an initial/icon fallback.
/// Listens to [ProfileStore] so every avatar updates after a change.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.fallback,
    this.backgroundColor = Colors.white,
    this.borderColor,
    this.borderWidth = 0,
    this.showCameraBadge = false,
  });

  final double size;
  final Widget? fallback;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showCameraBadge;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProfileStore.instance,
      builder: (context, _) {
        final bytes = ProfileStore.instance.avatarBytes;
        final border = borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: borderWidth,
              )
            : null;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: border,
              ),
              clipBehavior: Clip.antiAlias,
              child: bytes == null || bytes.isEmpty
                  ? Center(child: fallback)
                  : Image.memory(
                      bytes,
                      key: const ValueKey('avatar_image'),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, _, _) =>
                          Center(child: fallback),
                    ),
            ),
            if (showCameraBadge)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OxroColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
