import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/orders/presentation/screens/order_details_screen.dart';
import 'package:oxro/features/orders/presentation/screens/tracking_screen.dart';

/// 17 Order Success — ref 1:1 + premium: ambient bg (glow + dots +
/// navy wave + truck strip), delivery scene (box drop + tick badge +
/// dashed route + truck slide + pin), double confetti, ETA card +
/// copy, shine Track button.
class OrderSuccessScreen extends StatefulWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderSuccessScreen> createState() =>
      _OrderSuccessScreenState();
}

class _OrderSuccessScreenState
    extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _ambient;
  late final Animation<double> _box;
  late final Animation<double> _confetti;
  late final Animation<double> _confetti2;
  late final Animation<double> _text;
  late final Animation<Offset> _btnSlide;
  late final Animation<double> _truck;
  late final Animation<double> _shine;

  static const _confettiColors = [
    OxroColors.primary,
    OxroColors.royalBlue,
    Colors.green,
    Color(0xFFFFC107),
    Color(0xFFE91E63),
  ];

  String get _eta {
    final d = DateTime.now().add(const Duration(days: 5));
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _box = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.4,
            curve: Curves.elasticOut));
    _confetti = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.2, 0.9,
            curve: Curves.easeOut));
    _confetti2 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.45, 1.0,
            curve: Curves.easeOut));
    _text = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.45, 0.72,
            curve: Curves.easeOutCubic));
    _truck = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.35, 0.7,
            curve: Curves.easeOutCubic));
    _shine = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.7, 1.0,
            curve: Curves.easeOut));
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _c,
        curve: const Interval(0.6, 0.9,
            curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _c.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _copyId() {
    Clipboard.setData(
        ClipboardData(text: widget.orderId));
    showOxroSnack(context, 'Order ID copied');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) => CustomPaint(
                  painter: _BgPainter(
                      _ambient.value),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    EdgeInsets.all(context.padX + 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _scene(),
                    FadeTransition(
                      opacity: _text,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin:
                              const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(_text),
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Text(
                                'Order Placed!',
                                key: ValueKey(
                                    'success_title'),
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight:
                                        FontWeight.w800,
                                    color: OxroColors
                                        .charcoal)),
                            const SizedBox(height: 4),
                            AnimatedBuilder(
                              animation: _text,
                              builder: (context, _) =>
                                  Container(
                                height: 4,
                                width: 64 * _text.value,
                                decoration: BoxDecoration(
                                  gradient: OxroColors
                                      .gradient,
                                  borderRadius:
                                      BorderRadius
                                          .circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                                'Your order has been confirmed.\nYou will receive updates soon.',
                                textAlign:
                                    TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        OxroColors.muted,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              key: const ValueKey(
                                  'success_copy'),
                              onTap: _copyId,
                              behavior: HitTestBehavior
                                  .opaque,
                              child: Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        horizontal: 12,
                                        vertical: 6),
                                decoration: BoxDecoration(
                                  color: OxroColors
                                      .pageBg,
                                  borderRadius:
                                      BorderRadius
                                          .circular(16),
                                  border: Border.all(
                                      color: OxroColors
                                          .border),
                                ),
                                child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                          'Order ID: ${widget.orderId}',
                                          key: const ValueKey(
                                              'success_order_id'),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                                  fontSize:
                                                      12,
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                  color: OxroColors
                                                      .charcoal)),
                                    ),
                                    const SizedBox(
                                        width: 6),
                                    const Icon(
                                        Icons
                                            .copy_outlined,
                                        size: 14,
                                        color: OxroColors
                                            .muted),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              key: const ValueKey(
                                  'success_eta'),
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                  context.rs(12)),
                              decoration: BoxDecoration(
                                color:
                                    OxroColors.pageBg,
                                borderRadius:
                                    BorderRadius.circular(
                                        14),
                                border: Border.all(
                                    color: OxroColors
                                        .border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment:
                                        Alignment.center,
                                    decoration:
                                        BoxDecoration(
                                      color: OxroColors
                                          .primary
                                          .withValues(
                                              alpha:
                                                  0.12),
                                      shape:
                                          BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons
                                            .local_shipping_outlined,
                                        size: 20,
                                        color: OxroColors
                                            .primary),
                                  ),
                                  const SizedBox(
                                      width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                            'Arriving by $_eta',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style: const TextStyle(
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    FontWeight
                                                        .w800)),
                                        const Text(
                                            '100% Original • Easy returns • COD available',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style: TextStyle(
                                                fontSize:
                                                    11,
                                                color: OxroColors
                                                    .muted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SlideTransition(
                      position: _btnSlide,
                      child: FadeTransition(
                        opacity: _text,
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            _ShineBtn(
                              key: const ValueKey(
                                  'success_track'),
                              label: 'Track Order →',
                              shine: _shine,
                              onTap: () => pushScreen(
                                  context,
                                  TrackingScreen(
                                      orderId:
                                          widget.orderId)),
                            ),
                            const SizedBox(
                                height: 10),
                            GestureDetector(
                              key: const ValueKey(
                                  'success_details'),
                              onTap: () => pushScreen(
                                  context,
                                  OrderDetailsScreen(
                                      orderId:
                                          widget.orderId)),
                              behavior: HitTestBehavior
                                  .opaque,
                              child: Container(
                                width: double.infinity,
                                alignment:
                                    Alignment.center,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                        vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius
                                          .circular(12),
                                  border: Border.all(
                                      color: OxroColors
                                          .royalBlue,
                                      width: 1.5),
                                ),
                                child: const Text(
                                    'View Order Details',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        color: OxroColors
                                            .royalBlue)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              key: const ValueKey(
                                  'success_continue'),
                              onTap: () =>
                                  Navigator.of(context)
                                      .popUntil((route) =>
                                          route
                                              .isFirst),
                              behavior: HitTestBehavior
                                  .opaque,
                              child: const Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                        vertical: 8),
                                child: Text(
                                    'Continue Shopping',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        color: OxroColors
                                            .muted)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Delivery scene: peach disc + ring + box + tick badge + dashed
  /// route + sliding truck + pin + double confetti.
  Widget _scene() {
    return AnimatedBuilder(
      key: const ValueKey('success_box'),
      animation: _c,
      builder: (context, _) {
        final s = context.rs(120);
        final slide =
            (1 - _truck.value) * context.w * 0.5;
        return SizedBox(
          width: double.infinity,
          height: s + 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 22; i++)
                _dot(i, _confetti.value,
                    wide: true),
              for (var i = 0; i < 10; i++)
                _dot(i + 100,
                    _confetti2.value * 0.9,
                    wide: false),
              Container(
                width: s + 44,
                height: s + 44,
                decoration: BoxDecoration(
                  color: OxroColors.primary
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: s + 78,
                height: s + 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: OxroColors.primary
                          .withValues(alpha: 0.20),
                      width: 1.5),
                ),
              ),
              // Dashed route.
              Positioned(
                bottom: 34,
                left: 24,
                right: 24,
                child: CustomPaint(
                  size: const Size(
                      double.infinity, 2),
                  painter: _DashPainter(
                      _truck.value),
                ),
              ),
              // Sliding truck.
              Positioned(
                bottom: 18,
                left: 24 + slide * 0.4,
                child: Opacity(
                  opacity:
                      _truck.value.clamp(0.0, 1.0),
                  child: const Icon(
                      Icons
                          .local_shipping_outlined,
                      size: 30,
                      color:
                          OxroColors.royalBlue),
                ),
              ),
              // Box.
              Transform.scale(
                scale:
                    _box.value.clamp(0.01, 1.2),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: s,
                      height: s * 0.85,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE3CB),
                        borderRadius:
                            BorderRadius.circular(
                                20),
                        border: Border.all(
                            color: OxroColors.primary
                                .withValues(
                                    alpha: 0.35),
                            width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color:
                                Color(0x30051D47),
                            blurRadius: 24,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                          Icons
                              .inventory_2_outlined,
                          size: context.rs(58),
                          color:
                              OxroColors.primary),
                    ),
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Transform.scale(
                        scale: _text.value
                            .clamp(0.01, 1.0),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment:
                              Alignment.center,
                          decoration:
                              const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                    0x5566BB6A),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Pin.
              Positioned(
                right: 30,
                top: 6,
                child: Transform.translate(
                  offset: Offset(
                      0,
                      -6 *
                          math.sin(_truck.value *
                              math.pi)),
                  child: Opacity(
                    opacity: _truck.value
                        .clamp(0.0, 1.0),
                    child: const Icon(
                        Icons.location_on,
                        size: 30,
                        color: Color(0xFFE11D48)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dot(int i, double t,
      {required bool wide}) {
    final n = wide ? 22 : 10;
    final angle =
        (i / n) * math.pi * 2 + (wide ? 0.15 : 0.6);
    final dist =
        (wide ? 62 : 46) + (wide ? 66 : 50) * t;
    final color = _confettiColors[
        i % _confettiColors.length];
    final cx = wide ? 190.0 : 190.0;
    return Positioned(
      left: cx + dist * math.cos(angle) - 5,
      top: 105 + dist * math.sin(angle) - 5,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Container(
          width: 10 - (i % 3) * 2,
          height: 10 - (i % 3) * 2,
          decoration: BoxDecoration(
            color: color,
            shape: i.isEven
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: i.isEven
                ? null
                : BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Ambient bg: peach glow top + dot grid + navy wave + truck strip.
class _BgPainter extends CustomPainter {
  _BgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = OxroColors.primary
          .withValues(alpha: 0.10 + 0.03 * t);
    canvas.drawCircle(
        Offset(size.width * 0.5, 90), 150, glow);
    final dot = Paint()
      ..color = OxroColors.royalBlue
          .withValues(alpha: 0.10);
    for (double x = 16; x < size.width; x += 26) {
      for (double y = 150; y < 260; y += 26) {
        canvas.drawCircle(
            Offset(x, y + 4 * t), 1.6, dot);
      }
    }
    final wave = Paint()
      ..color = OxroColors.navyDark
          .withValues(alpha: 0.05);
    final path = Path()
      ..moveTo(0, size.height - 90)
      ..quadraticBezierTo(size.width * 0.5,
          size.height - 110 - 8 * t, size.width, size.height - 90)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(
          covariant _BgPainter old) =>
      old.t != t;
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    final paint = Paint()
      ..color = OxroColors.primary
          .withValues(alpha: 0.55)
      ..strokeWidth = 2;
    const dash = 7.0;
    const gap = 6.0;
    final total = size.width * p.clamp(0.0, 1.0);
    var x = 0.0;
    while (x < total) {
      canvas.drawLine(Offset(x, 0),
          Offset(math.min(x + dash, total), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(
          covariant _DashPainter old) =>
      old.p != p;
}

/// Solid primary button with one-time shine sweep + press scale.
class _ShineBtn extends StatefulWidget {
  const _ShineBtn(
      {super.key,
      required this.label,
      required this.shine,
      required this.onTap});

  final String label;
  final Animation<double> shine;
  final VoidCallback onTap;

  @override
  State<_ShineBtn> createState() => _ShineBtnState();
}

class _ShineBtnState extends State<_ShineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.value = 0.96,
      onTapUp: (_) => _press.value = 1.0,
      onTapCancel: () => _press.value = 1.0,
      onTap: () {
        _press.value = 1.0;
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _press,
        child: AnimatedBuilder(
          animation: widget.shine,
          builder: (context, _) => Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
                vertical: 14),
            decoration: BoxDecoration(
              color: OxroColors.primary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40051D47),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                // Shine sweep.
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),
                    child: Transform.translate(
                      offset: Offset(
                          -220 +
                              440 *
                                  widget.shine.value,
                          0),
                      child: Transform.rotate(
                        angle: 0.35,
                        child: Container(
                          width: 46,
                          color: Colors.white
                              .withValues(
                                  alpha: 0.30 *
                                      (1 -
                                          widget.shine
                                              .value)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
