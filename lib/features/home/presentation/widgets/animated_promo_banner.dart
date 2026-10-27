import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/widgets/promo_motion.dart';

/// Premium looping hero used by the standard catalogue banners.
///
/// Each slide keeps its own palette: the gradient, rays and stickers are all
/// derived from [HomeBanner.colors], while the food plate uses
/// [HomeBanner.imageUrl]. The 5 s loop mirrors the carousel's auto-advance and
/// offscreen pages are paused by the caller via [TickerMode].
class AnimatedPromoBanner extends StatefulWidget {
  const AnimatedPromoBanner({
    super.key,
    required this.banner,
    required this.index,
    required this.onTap,
  });

  final HomeBanner banner;
  final int index;
  final VoidCallback onTap;

  @override
  State<AnimatedPromoBanner> createState() => _AnimatedPromoBannerState();
}

class _AnimatedPromoBannerState extends State<AnimatedPromoBanner>
    with TickerProviderStateMixin {
  static const _loopDuration = Duration(seconds: 5);
  static const _spinDuration = Duration(seconds: 26);

  late final AnimationController _loop;
  late final AnimationController _spin;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: _loopDuration);
    _spin = AnimationController(vsync: this, duration: _spinDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce) {
        _loop.stop();
        _spin.stop();
        _loop.value = 0.62;
        _spin.value = 0.1;
      }
    }
    if (!_started) {
      _started = true;
      if (!reduce) {
        _loop.repeat();
        _spin.repeat();
      }
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _spin.dispose();
    super.dispose();
  }

  double _seg(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = widget.banner.colors;
    final base = colors.isNotEmpty ? colors.first : const Color(0xFFE23744);
    final deep = colors.length > 1 ? colors.last : const Color(0xFFB3121C);
    final rayLight = Color.lerp(base, deep, 0.32)!;
    final rayDark = Color.lerp(base, deep, 0.58)!;
    final ink = Color.lerp(deep, Colors.black, 0.55)!;
    final badge = Color.lerp(base, Colors.white, 0.72)!;

    return GestureDetector(
      key: ValueKey('food_banner_${widget.index}'),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final lines = splitPromoTitle(widget.banner.title.toUpperCase());
          final longest = lines.fold<int>(
            1,
            (max, line) => math.max(max, line.length),
          );
          final available = width * 0.64 - 18;
          final titleSize = (available / (longest * 0.68)).clamp(19.0, 28.0);

          return AnimatedBuilder(
            animation: Listenable.merge([_loop, _spin]),
            builder: (context, _) {
              final t = _loop.value;
              final exit = _reduceMotion ? 1.0 : 1 - _seg(t, 0.93, 1.0);
              final shimmer = _reduceMotion ? 0.5 : t;

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [base, deep],
                        ),
                      ),
                      child: CustomPaint(
                        painter: PromoStarburstPainter(
                          progress: _reduceMotion ? 0.1 : _spin.value,
                          light: rayLight,
                          dark: rayDark,
                          bloom: 0.1,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: PromoShimmerPainter(progress: shimmer),
                      ),
                    ),
                  ),
                  PromoSparkleField(
                    t: t,
                    width: width,
                    height: height,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  for (var i = 0; i < 3; i++)
                    PromoFlyingSticker(
                      index: i,
                      t: t,
                      reduceMotion: _reduceMotion,
                      width: width,
                      height: height,
                      background: badge,
                      ink: ink,
                    ),
                  Positioned(
                    left: 18,
                    top: 34,
                    right: width * 0.36,
                    bottom: 58,
                    child: Opacity(
                      opacity: exit,
                      child: Transform.rotate(
                        angle: -0.035,
                        child: Transform.scale(
                          scale: _reduceMotion
                              ? 1
                              : 1 + 0.015 * math.sin(t * math.pi * 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < lines.length; i++)
                                PromoPopIn(
                                  t: t,
                                  start: 0.02 + i * 0.09,
                                  end: 0.3 + i * 0.09,
                                  reduceMotion: _reduceMotion,
                                  child: PromoOutlinedText(
                                    text: lines[i],
                                    size: titleSize,
                                    fill: const Color(0xFFFFF6E6),
                                    strokeColor: ink,
                                    strokeWidth: titleSize * 0.17,
                                    maxLines: 1,
                                  ),
                                ),
                              const SizedBox(height: 5),
                              PromoPopIn(
                                t: t,
                                start: 0.24,
                                end: 0.5,
                                reduceMotion: _reduceMotion,
                                child: Text(
                                  widget.banner.sub,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontSize: 11,
                                    height: 1.22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.banner.tag != null)
                    Positioned(
                      right: 14,
                      top: 34,
                      child: Opacity(
                        opacity: exit,
                        child: PromoOfferSeal(
                          tag: widget.banner.tag!,
                          t: t,
                          reduceMotion: _reduceMotion,
                          ink: ink,
                          size: (width * 0.38).clamp(108.0, 150.0),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 30,
                    child: Opacity(
                      opacity: exit,
                      child: PromoPopIn(
                        t: t,
                        start: 0.4,
                        end: 0.66,
                        reduceMotion: _reduceMotion,
                        child: Center(
                          child: Container(
                            key: ValueKey('banner_cta_${widget.index}'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.banner.cta,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: badge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
