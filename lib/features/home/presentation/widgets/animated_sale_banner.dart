import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/features/home/data/home_data.dart';
import 'package:oxro/features/home/presentation/widgets/promo_motion.dart';

/// Loop-animated "ITEMS AT 50% OFF" hero, modelled on the reference promo:
/// a slowly rotating starburst, snapping outlined headline, popping food
/// plate, flying offer stickers and a glossy light sweep.
///
/// The loop is 5 s to line up with the home carousel's auto-advance. Offscreen
/// pages are paused by the caller with [TickerMode]; reduced-motion users get a
/// static frame.
class AnimatedSaleBanner extends StatefulWidget {
  const AnimatedSaleBanner({
    super.key,
    required this.banner,
    required this.index,
    required this.onTap,
  });

  final HomeBanner banner;
  final int index;
  final VoidCallback onTap;

  @override
  State<AnimatedSaleBanner> createState() => _AnimatedSaleBannerState();
}

class _AnimatedSaleBannerState extends State<AnimatedSaleBanner>
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
    return GestureDetector(
      key: ValueKey('food_banner_${widget.index}'),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE23744), Color(0xFFB3121C)],
                        ),
                      ),
                      child: CustomPaint(
                        painter: PromoStarburstPainter(
                          progress: _reduceMotion ? 0.1 : _spin.value,
                          light: const Color(0xFFDF2F3C),
                          dark: const Color(0xFFC11E2A),
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
                  PromoSparkleField(t: t, width: width, height: height),
                  for (var i = 0; i < 3; i++)
                    PromoFlyingSticker(
                      index: i,
                      t: t,
                      reduceMotion: _reduceMotion,
                      width: width,
                      height: height,
                    ),
                  Positioned(
                    left: 18,
                    top: 34,
                    right: width * 0.36,
                    bottom: 58,
                    child: Opacity(
                      opacity: exit,
                      child: Transform.rotate(
                        angle: -0.04,
                        child: Transform.scale(
                          scale: _reduceMotion
                              ? 1
                              : 1 + 0.015 * math.sin(t * math.pi * 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PromoPopIn(
                                t: t,
                                start: 0.02,
                                end: 0.3,
                                reduceMotion: _reduceMotion,
                                child: PromoOutlinedText(
                                  text: 'ITEMS AT',
                                  size:
                                      (width * 0.105).clamp(30.0, 42.0) * 0.52,
                                  fill: const Color(0xFFFFD23F),
                                  strokeWidth: 4.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              PromoPopIn(
                                t: t,
                                start: 0.1,
                                end: 0.4,
                                reduceMotion: _reduceMotion,
                                child: PromoOutlinedText(
                                  text: '50% OFF',
                                  size: (width * 0.105).clamp(30.0, 42.0),
                                  fill: const Color(0xFFFFD23F),
                                  strokeWidth: 7,
                                ),
                              ),
                              const SizedBox(height: 4),
                              PromoPopIn(
                                t: t,
                                start: 0.24,
                                end: 0.5,
                                reduceMotion: _reduceMotion,
                                child: Text(
                                  widget.banner.sub,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    height: 1.2,
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
                              color: const Color(0xFF191415),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
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
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Color(0xFFFFD23F),
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
