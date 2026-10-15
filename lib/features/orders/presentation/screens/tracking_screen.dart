import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/orders/data/order_store.dart';

/// 18 Order Tracking — ref 1:1 + premium: sequential node pops,
/// progressive rail draw, current pulse loop, truck slide, ETA card.
/// Calm utility (no confetti).
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<TrackingScreen> createState() =>
      _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = OrderStore.instance;
    final status = store.statusOf(widget.orderId);
    final steps = store.trackingSteps(widget.orderId);
    final eta = store.etaFor(widget.orderId);
    final done = status == OrderStatus.delivered
        ? 5
        : switch (status) {
            OrderStatus.processing => 1,
            OrderStatus.shipped => 3,
            OrderStatus.outForDelivery => 4,
            OrderStatus.delivered => 5,
            OrderStatus.cancelled => 1,
          };
    final heroColor = status == OrderStatus.delivered
        ? Colors.green
        : OxroColors.royalBlue;
    final heroLabel = switch (status) {
      OrderStatus.processing => 'Processing',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.outForDelivery => 'Out for delivery',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) => CustomPaint(
                  painter: _TrackBgPainter(
                      _ambient.value),
                ),
              ),
            ),
            Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.rs(8), vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back,
                        color: OxroColors.charcoal),
                  ),
                  Expanded(
                    child: Text('Track Order',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: context.font(17),
                            fontWeight: FontWeight.w800,
                            color: OxroColors.charcoal)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.padX),
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      key: const ValueKey('track_copy'),
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: widget.orderId));
                        showOxroSnack(
                            context, 'Order ID copied');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                                'Order ID: ${widget.orderId}',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color:
                                        OxroColors.muted)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                              Icons.copy_outlined,
                              size: 13,
                              color: OxroColors.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _ambient,
                    builder: (context, _) =>
                        Container(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6),
                      decoration: BoxDecoration(
                        color: heroColor.withValues(
                            alpha: 0.10 +
                                0.04 *
                                    _ambient.value),
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: heroColor,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                              status ==
                                      OrderStatus
                                          .delivered
                                  ? heroLabel
                                  : '$heroLabel • $eta',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: heroColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.rs(8)),
            Expanded(
              child: ListView(
                key: const ValueKey('track_screen'),
                padding: EdgeInsets.fromLTRB(
                    context.padX, 8, context.padX, 16),
                children: [
                  AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final p = Curves.easeOut.transform(
                          _c.value.clamp(0.0, 1.0));
                      return CustomPaint(
                        painter: _RailPainter(p),
                        child: Column(
                          children: [
                            for (var i = 0;
                                i < steps.length;
                                i++)
                              _node(
                                  i,
                                  steps[i],
                                  done,
                                  status),
                            // Truck at rail bottom.
                            Align(
                              alignment:
                                  Alignment.centerLeft,
                              child: TweenAnimationBuilder<
                                  double>(
                                tween: Tween(
                                    begin: 0.0,
                                    end: 1.0),
                                duration:
                                    const Duration(
                                        milliseconds:
                                            600),
                                curve: Curves.easeOut,
                                builder:
                                    (context, v, _) =>
                                        Transform
                                            .translate(
                                  offset: Offset(
                                      60 * v, 0),
                                  child: Opacity(
                                    opacity: v
                                        .clamp(0.0, 1.0),
                                    child:
                                        const Padding(
                                      padding:
                                          EdgeInsets.only(
                                              top: 8,
                                              left: 14),
                                      child: Icon(
                                          Icons
                                              .local_shipping_outlined,
                                          size: 30,
                                          color: OxroColors
                                              .royalBlue),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(height: context.rs(12)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(
                        milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) {
                      final t = v.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset:
                              Offset(0, 12 * (1 - t)),
                          child: Container(
                            key: const ValueKey(
                                'track_eta'),
                            width: double.infinity,
                            padding: EdgeInsets.all(
                                context.rs(12)),
                            decoration: BoxDecoration(
                              color: OxroColors.pageBg,
                              borderRadius:
                                  BorderRadius.circular(
                                      14),
                              border: Border.all(
                                  color:
                                      OxroColors.border),
                            ),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Row(
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
                                            alpha: 0.12),
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
                                          status ==
                                                  OrderStatus
                                                      .delivered
                                              ? 'Delivered • enjoy!'
                                              : 'Arriving by $eta',
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                                  fontSize:
                                                      13,
                                                  fontWeight:
                                                      FontWeight
                                                          .w800)),
                                      const Text(
                                          '123, Anna Nagar, Chennai — 600040',
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: OxroColors
                                                  .muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const _RouteStrip(),
                          ],
                        ),
                        ),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  /// Per-stage chip tints (done/current icon backgrounds).
  static const _stageTints = [
    Color(0xFFFFE3CB),
    Color(0xFFD8EBFF),
    Color(0xFFFFF3D6),
    Color(0xFFE6E6FA),
    Color(0xFFD9F2E6),
  ];

  static const _stageInks = [
    OxroColors.primary,
    OxroColors.royalBlue,
    Color(0xFFB45309),
    Color(0xFF6D28D9),
    Colors.green,
  ];

  Widget _node(int i, TrackingStep s, int done,
      OrderStatus status) {
    final isDone = i < done;
    final isCurrent = i == done &&
        status != OrderStatus.delivered;
    final color = isDone
        ? Colors.green
        : isCurrent
            ? OxroColors.royalBlue
            : OxroColors.border;
    final chipBg = isDone || isCurrent
        ? _stageTints[i % _stageTints.length]
        : Colors.white;
    final chipInk = isDone
        ? Colors.green
        : isCurrent
            ? _stageInks[i % _stageInks.length]
            : OxroColors.muted;
    return TweenAnimationBuilder<double>(
      key: ValueKey('track_node_$i'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + i * 150),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final t = v.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.7 + 0.3 * t,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Node dot (current pulses via ambient).
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, _) =>
                          Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withValues(
                                  alpha: 0.35 +
                                      0.3 *
                                          _ambient
                                              .value),
                              width: 3),
                        ),
                        child: Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: chipBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: color, width: 1.5),
                          ),
                          child: Icon(s.icon,
                              size: 14,
                              color: chipInk),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDone
                            ? chipBg
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDone
                                ? Colors.green
                                : OxroColors.border,
                            width: 2),
                      ),
                      child: Icon(
                          isDone
                              ? Icons.check
                              : s.icon,
                          size: 15,
                          color: isDone
                              ? Colors.green
                              : OxroColors.muted),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isDone ||
                                        isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: isDone ||
                                        isCurrent
                                    ? OxroColors.charcoal
                                    : OxroColors
                                        .muted)),
                        Text(s.time,
                            style: const TextStyle(
                                fontSize: 12,
                                color:
                                    OxroColors.muted)),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    AnimatedBuilder(
                      animation: _ambient,
                      builder: (context, _) => Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3),
                        decoration: BoxDecoration(
                          color: OxroColors.royalBlue
                              .withValues(
                                  alpha: 0.10 +
                                      0.06 *
                                          _ambient
                                              .value),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: const Text('now',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w800,
                                color: OxroColors
                                    .royalBlue)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mini dashed truck→pin route strip inside the ETA card.
class _RouteStrip extends StatelessWidget {
  const _RouteStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 30,
            right: 30,
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _StripDashPainter(),
            ),
          ),
          const Positioned(
            left: 8,
            child: Icon(
                Icons.local_shipping_outlined,
                size: 22,
                color: OxroColors.royalBlue),
          ),
          const Positioned(
            right: 8,
            child: Icon(Icons.location_on,
                size: 22, color: Color(0xFFE11D48)),
          ),
          Positioned(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: OxroColors.primary,
                  shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          OxroColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 2;
    const dash = 6.0;
    const gap = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0),
          Offset((x + dash).clamp(0, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

/// Progressive vertical rail behind the nodes + truck marker
/// riding the progress point.
class _RailPainter extends CustomPainter {
  _RailPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final x = 17.0;
    final top = 24.0;
    final bottom = size.height - 70.0;
    if (bottom <= top) return;
    final prog = p.clamp(0.0, 1.0);
    canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..color = OxroColors.border
          ..strokeWidth = 2.5);
    // Faint full-route dashes (watermark).
    final dash = Paint()
      ..color = OxroColors.royalBlue.withValues(alpha: 0.18)
      ..strokeWidth = 2.5;
    var y = top;
    while (y < bottom) {
      canvas.drawLine(Offset(x + 7, y),
          Offset(x + 7, (y + 5).clamp(top, bottom)), dash);
      y += 10;
    }
    final py = top + (bottom - top) * prog;
    canvas.drawLine(
        Offset(x, top),
        Offset(x, py),
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2.5);
    // Truck marker at progress point.
    canvas.drawCircle(
        Offset(x, py),
        9,
        Paint()..color = Colors.white);
    canvas.drawCircle(
        Offset(x, py),
        9,
        Paint()
          ..color = OxroColors.royalBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    canvas.drawCircle(
        Offset(x, py),
        3.5,
        Paint()..color = OxroColors.royalBlue);
  }

  @override
  bool shouldRepaint(
          covariant _RailPainter old) =>
      old.p != p;
}

/// Ambient bg (pairs with 16/17): peach glow + dot grid + navy wave.
class _TrackBgPainter extends CustomPainter {
  _TrackBgPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = OxroColors.primary
          .withValues(alpha: 0.06 + 0.02 * t);
    canvas.drawCircle(
        Offset(size.width * 0.5, 110), 140, glow);
    final dot = Paint()
      ..color = OxroColors.royalBlue
          .withValues(alpha: 0.08);
    for (double x = 16; x < size.width; x += 28) {
      for (double y = 200; y < 320; y += 28) {
        canvas.drawCircle(
            Offset(x, y + 4 * t), 1.5, dot);
      }
    }
    final wave = Paint()
      ..color = OxroColors.navyDark
          .withValues(alpha: 0.045);
    final path = Path()
      ..moveTo(0, size.height - 80)
      ..quadraticBezierTo(size.width * 0.5,
          size.height - 100 - 8 * t, size.width, size.height - 80)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(
          covariant _TrackBgPainter old) =>
      old.t != t;
}
