import 'package:flutter/material.dart';

import 'package:oxro/app/widgets/video_banner.dart';
import 'package:oxro/features/home/data/home_data.dart';

/// Video-backed home hero slide.
///
/// Plays a muted looping food clip as the background with a dark bottom scrim
/// so the title, subtitle, offer tag and CTA stay readable. Off-screen slides
/// are paused by the carousel via [play]. When the clip cannot be initialised
/// (e.g. widget tests) [VideoBanner] falls back to the banner photo, then to a
/// gradient, so the layout and keys stay intact.
class VideoHeroBanner extends StatelessWidget {
  const VideoHeroBanner({
    super.key,
    required this.banner,
    required this.index,
    required this.onTap,
    this.play = true,
  });

  final HomeBanner banner;
  final int index;
  final VoidCallback onTap;

  /// Whether this slide is the visible page (drives video playback).
  final bool play;

  @override
  Widget build(BuildContext context) {
    final accent = banner.colors.isNotEmpty
        ? banner.colors.first
        : const Color(0xFFFF6A00);

    return GestureDetector(
      key: ValueKey('food_banner_$index'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final titleSize = (width * 0.078).clamp(22.0, 34.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              VideoBanner(
                asset: banner.videoUrl ?? '',
                fallbackAsset: banner.imageUrl,
                fit: BoxFit.cover,
                play: play,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xD9000000)],
                    stops: [0.28, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: -50,
                bottom: -70,
                child: IgnorePointer(
                  child: Container(
                    width: width * 0.95,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.42),
                          accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (banner.tag != null)
                Positioned(
                  left: 18,
                  top: 26,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      banner.tag!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: titleSize,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: Color(0xE6FFFFFF),
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 30,
                child: Center(
                  child: Container(
                    key: ValueKey('banner_cta_$index'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            banner.cta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
