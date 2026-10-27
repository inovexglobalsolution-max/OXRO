import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared premium motion pieces for the animated home promo heroes.

/// Slowly rotating sunburst with a soft centre bloom and vignette.
class PromoStarburstPainter extends CustomPainter {
  const PromoStarburstPainter({
    required this.progress,
    required this.light,
    required this.dark,
    this.spokes = 24,
    this.bloom = 0.16,
  });

  final double progress;
  final Color light;
  final Color dark;
  final int spokes;
  final double bloom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final center = size.center(Offset.zero);
    final maxR = size.longestSide * 1.05;
    final paint = Paint();
    for (var i = 0; i < spokes; i++) {
      final a0 = progress * math.pi * 2 + (i * 2 * math.pi / spokes);
      final a1 = a0 + (math.pi / spokes) * 1.02;
      paint.color = i.isEven ? light : dark;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + maxR * math.cos(a0),
          center.dy + maxR * math.sin(a0),
        )
        ..lineTo(
          center.dx + maxR * math.cos(a1),
          center.dy + maxR * math.sin(a1),
        )
        ..close();
      canvas.drawPath(path, paint);
    }

    final bloomRect = Rect.fromCircle(center: center, radius: size.shortestSide);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: bloom),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.85],
        ).createShader(bloomRect),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x52000000)],
          stops: [0.5, 1.0],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PromoStarburstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.light != light ||
      oldDelegate.dark != dark;
}

/// Diagonal soft light sweep used to make headlines feel glossy.
class PromoShimmerPainter extends CustomPainter {
  const PromoShimmerPainter({
    required this.progress,
    this.color = const Color(0x38FFFFFF),
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width + progress * size.width * 2.6;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0x00FFFFFF), color, const Color(0x00FFFFFF)],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlidingGradient(x / size.width),
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PromoShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.fraction);

  final double fraction;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * fraction, 0, 0);
}

/// Chunky outlined display text, sticker-style.
class PromoOutlinedText extends StatelessWidget {
  const PromoOutlinedText({
    super.key,
    required this.text,
    required this.size,
    required this.fill,
    this.strokeColor = const Color(0xFF1A1011),
    this.strokeWidth = 7,
    this.italic = true,
    this.textAlign = TextAlign.left,
    this.maxLines = 2,
  });

  final String text;
  final double size;
  final Color fill;
  final Color strokeColor;
  final double strokeWidth;
  final bool italic;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: size,
      height: 1.02,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      shadows: const [
        Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 4)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Text(
            text,
            maxLines: maxLines,
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..color = strokeColor,
            ),
          ),
          Text(
            text,
            maxLines: maxLines,
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(color: fill),
          ),
        ],
      ),
    );
  }
}

/// Elastic entrance for a single line, with an optional continuous bob.
class PromoPopIn extends StatelessWidget {
  const PromoPopIn({
    super.key,
    required this.t,
    required this.start,
    required this.end,
    required this.reduceMotion,
    required this.child,
    this.alignment = Alignment.centerLeft,
    this.from = 0.4,
    this.floatAmplitude = 0,
    this.floatSpeed = 1,
  });

  final double t;
  final double start;
  final double end;
  final bool reduceMotion;
  final Widget child;
  final Alignment alignment;
  final double from;
  final double floatAmplitude;
  final double floatSpeed;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    final p = ((t - start) / (end - start)).clamp(0.0, 1.0);
    final scale = from + (1 - from) * Curves.elasticOut.transform(p);
    final opacity = ((t - start) / ((end - start) * 0.35)).clamp(0.0, 1.0);
    final bob = floatAmplitude == 0
        ? 0.0
        : math.sin(t * math.pi * 2 * floatSpeed) * floatAmplitude;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Transform.scale(
          scale: scale,
          alignment: alignment,
          child: child,
        ),
      ),
    );
  }
}

/// Popping, floating offer seal with big outlined deal text.
class PromoOfferSeal extends StatelessWidget {
  const PromoOfferSeal({
    super.key,
    required this.tag,
    required this.t,
    required this.reduceMotion,
    required this.size,
    this.ink = const Color(0xFF1A1011),
    this.start = 0.12,
  });

  final String tag;
  final double t;
  final bool reduceMotion;
  final double size;
  final Color ink;
  final double start;

  @override
  Widget build(BuildContext context) {
    final p = reduceMotion ? 1.0 : ((t - start) / 0.34).clamp(0.0, 1.0);
    final scale = 0.2 + 0.8 * Curves.elasticOut.transform(p);
    final opacity = ((t - start) / 0.12).clamp(0.0, 1.0);
    final float = reduceMotion ? 0.0 : math.sin(t * math.pi * 2) * 4.5;
    final tilt = reduceMotion ? 0.0 : math.sin(t * math.pi * 2 + 0.6) * 0.05;

    final base = TextStyle(
      fontSize: size * 0.26,
      height: 1.0,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.2,
      shadows: const [
        Shadow(color: Color(0x4D000000), blurRadius: 8, offset: Offset(0, 4)),
      ],
    );

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, float),
        child: Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              padding: EdgeInsets.symmetric(horizontal: size * 0.14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        tag,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: base.copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = size * 0.05
                            ..strokeJoin = StrokeJoin.round
                            ..color = ink,
                        ),
                      ),
                      Text(
                        tag,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: base.copyWith(color: const Color(0xFFFFF6E6)),
                      ),
                    ],
                  ),
                  SizedBox(height: size * 0.04),
                  Text(
                    'LIMITED OFFER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: size * 0.062,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offer badge gliding across the hero on a curved path.
class PromoFlyingSticker extends StatelessWidget {
  const PromoFlyingSticker({
    super.key,
    required this.index,
    required this.t,
    required this.reduceMotion,
    required this.width,
    required this.height,
    this.background = const Color(0xFFFFD23F),
    this.ink = const Color(0xFF1A1011),
    this.count = 3,
  });

  final int index;
  final double t;
  final bool reduceMotion;
  final double width;
  final double height;
  final Color background;
  final Color ink;
  final int count;

  static const _bases = [0.44, 0.30, 0.60, 0.38];
  static const _sizes = [30.0, 24.0, 26.0, 22.0];
  static const _amps = [34.0, 26.0, 40.0, 30.0];

  @override
  Widget build(BuildContext context) {
    final p = reduceMotion
        ? 0.3 + index * 0.18
        : ((t * 1.15) - index * 0.21) % 1.0;
    final x = -40 + p * (width + 80);
    final y =
        height * _bases[index % _bases.length] +
        math.sin(p * math.pi * 2) * _amps[index % _amps.length];
    final visible = reduceMotion
        ? 1.0
        : (math.sin(p * math.pi)).clamp(0.0, 1.0);
    final rotation = reduceMotion ? 0.0 : p * math.pi * 1.4;
    final size = _sizes[index % _sizes.length];

    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: visible,
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: ink, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: switch (index % 3) {
                0 => Icon(Icons.bolt_rounded, size: size * 0.66, color: ink),
                1 => Text(
                  '₹',
                  style: TextStyle(
                    fontSize: size * 0.55,
                    fontWeight: FontWeight.w900,
                    color: ink,
                    height: 1,
                  ),
                ),
                _ => Icon(
                  Icons.star_rounded,
                  size: size * 0.58,
                  color: ink,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Dust motes drifting upward behind the content.
class PromoSparkleField extends StatelessWidget {
  const PromoSparkleField({
    super.key,
    required this.t,
    required this.width,
    required this.height,
    this.color = const Color(0x99FFFFFF),
    this.count = 7,
  });

  final double t;
  final double width;
  final double height;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            _sparkle(i),
        ],
      ),
    );
  }

  Widget _sparkle(int i) {
    final seedX = (i * 0.173 + 0.07) % 1.0;
    final speed = 0.35 + (i % 3) * 0.16;
    final drift = (t * speed + i * 0.13) % 1.0;
    final y = height * (1.05 - drift * 1.1);
    final x = width * seedX + math.sin((drift + i) * math.pi * 2) * 10;
    final size = 3.0 + (i % 3) * 1.6;
    final opacity = (math.sin(drift * math.pi)).clamp(0.0, 1.0) * 0.9;
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color, blurRadius: size * 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Splits a promo title into at most two balanced display lines.
List<String> splitPromoTitle(String title, {int maxLines = 2}) {
  final words = title.trim().split(RegExp(r'\s+'));
  if (words.length <= 1 || maxLines <= 1) return [title.trim()];
  final lines = <String>[];
  final perLine = (words.length / math.min(maxLines, words.length)).ceil();
  for (var i = 0; i < words.length; i += perLine) {
    lines.add(
      words.sublist(i, math.min(i + perLine, words.length)).join(' '),
    );
  }
  return lines;
}
