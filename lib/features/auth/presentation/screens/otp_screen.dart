import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/router/oxro_routes.dart';
import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/app/widgets/oxro_button.dart';
import 'package:oxro/app/widgets/oxro_snack.dart';
import 'package:oxro/features/account/data/profile_store.dart';
import 'package:oxro/features/home/presentation/screens/home_screen.dart';

/// 05 OTP Verification — reference minimal white style, native keyboard.
/// 6 real fields: autofocus first box opens the phone's number keyboard,
/// auto-advance, backspace nav, paste-distribute, done submits.
/// Whole block vertically centered. Demo: any 6 digits accepted.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.contact,
    this.name,
    this.isNewUser = false,
  });

  /// Email address (or mobile for legacy flows) receiving the OTP.
  final String contact;
  final String? name;
  final bool isNewUser;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with TickerProviderStateMixin {
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _nodes;
  int _pos = 0;
  String? _error;
  bool _success = false;

  Timer? _timer;
  int _left = 45;

  /// Brute-force guard: 5 failed submits → 30s Verify cooldown.
  static const _maxAttempts = 5;
  static const _lockout = Duration(seconds: 30);
  int _attempts = 0;
  DateTime? _lockedUntil;

  bool get _locked {
    final until = _lockedUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _lockedUntil = null;
      _attempts = 0;
      return false;
    }
    return true;
  }

  int get _lockLeft {
    final until = _lockedUntil;
    if (until == null) return 0;
    return until.difference(DateTime.now()).inSeconds.clamp(0, 30);
  }

  late final AnimationController _shake;
  late final AnimationController _pop;
  late final AnimationController _bg;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(6, (_) => TextEditingController());
    _nodes = List.generate(6, (_) => FocusNode());
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    // No setState here: called from initState where a direct
    // assignment avoids a redundant rebuild (extra jump).
    _left = 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        setState(() => _left = 0);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _shake.dispose();
    _pop.dispose();
    _bg.dispose();
    super.dispose();
  }

  bool get _isEmail => widget.contact.contains('@');

  String get _masked {
    final c = widget.contact;
    if (RegExp(r'^\d{10}$').hasMatch(c)) {
      return '+91 ${c.substring(0, 5)} ${c.substring(5)}';
    }
    return c;
  }

  void _handleChanged(int i, String v) {
    if (_success) return;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Paste / autofill — distribute from this box.
      setState(() {
        for (var k = 0; k < 6; k++) {
          final idx = i + k;
          if (idx < 6 && k < digits.length) {
            _ctrls[idx].text = digits[k];
          }
        }
        _error = null;
      });
      _pop.forward(from: 0);
      final next = _firstEmpty();
      _nodes[next].requestFocus();
      setState(() => _pos = next);
      return;
    }
    if (digits.isEmpty) {
      // Cleared (backspace) — move to previous box.
      setState(() => _error = null);
      if (i > 0) {
        _nodes[i - 1].requestFocus();
        setState(() => _pos = i - 1);
      }
      return;
    }
    // Single digit typed — advance.
    if (_ctrls[i].text != digits) {
      // Normalize (e.g. field had stale text).
      _ctrls[i].text = digits;
    }
    setState(() => _error = null);
    _pop.forward(from: 0);
    if (i < 5) {
      _nodes[i + 1].requestFocus();
      setState(() => _pos = i + 1);
    } else {
      _nodes[i].unfocus();
    }
  }

  int _firstEmpty() {
    for (var i = 0; i < 6; i++) {
      if (_ctrls[i].text.isEmpty) return i;
    }
    return 5;
  }

  void _fail(String msg) {
    _attempts++;
    if (_attempts >= _maxAttempts) {
      _lockedUntil = DateTime.now().add(_lockout);
      _attempts = 0;
      setState(() => _error =
          'Too many attempts — try again in 30s');
    } else {
      setState(() => _error = msg);
    }
    _shake.forward(from: 0);
  }

  Future<void> _verify() async {
    if (_success) return;
    if (_locked) {
      setState(() =>
          _error = 'Try again in ${_lockLeft}s');
      _shake.forward(from: 0);
      return;
    }
    final complete = _ctrls.every((c) => c.text.isNotEmpty);
    if (!complete) {
      _fail('Enter all 6 digits');
      return;
    }
    setState(() {
      _error = null;
      _success = true;
    });
    HapticFeedback.mediumImpact();
    // Email vs phone are separate identities — never file a
    // phone number under email.
    final contact = widget.contact.trim();
    if (contact.contains('@')) {
      await ProfileStore.instance.save(
        email: contact,
        name: widget.name,
      );
    } else {
      await ProfileStore.instance.save(
        phone: contact,
        name: widget.name,
      );
    }
    // Let the success burst animation play before leaving.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    replaceAllWith(
      context,
      HomeScreen(
        welcomeName:
            widget.isNewUser ? widget.name : null,
      ),
    );
  }

  void _resend() {
    if (_left > 0 || _success) return;
    setState(() {
      for (final c in _ctrls) {
        c.clear();
      }
      _pos = 0;
      _error = null;
    });
    _nodes[0].requestFocus();
    _startTimer();
    showOxroSnack(
        context,
        _isEmail
            ? 'OTP resent to your email'
            : 'OTP resent to your mobile');
  }

  @override
  Widget build(BuildContext context) {
    // Box size fits 320 too: (320 - 2*padX - 5*8) / 6 ≈ 38.
    final box =
        (context.w - context.padX * 2 - 5 * context.rs(8)) / 6;
    final boxSize = box.clamp(36.0, 46.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFFEEDF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF6), Color(0xFFFFE9D6)],
          ),
        ),
        child: Stack(
          children: [
            // Same premium animated background as login.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bg,
                builder: (context, child) {
                  final t = _bg.value;
                  return Stack(
                    children: [
                      Positioned(
                        top: -70 +
                            14 * math.sin(t * math.pi * 2),
                        right: -60,
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 150 +
                            12 * math.cos(t * math.pi * 2),
                        left: -80,
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            color: OxroColors.blue
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -90,
                        right: -70,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: OxroColors.primary
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: context.maxContentW),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header stays top.
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.rs(8), vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Text('Verify Your Number',
                              style: TextStyle(
                                  fontSize: context.font(16),
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    // Everything else — vertically centered middle.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (ctx, vp) =>
                            SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: vp.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  // Center logo (matches login).
                                  Center(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(
                                              context.rs(14)),
                                      child: Image.asset(
                                        'assets/logo/oxro_logo.jpeg',
                                        width: (context.w * 0.14)
                                            .clamp(44.0, 60.0),
                                        height: (context.w * 0.14)
                                            .clamp(44.0, 60.0),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (ctx, err, stack) =>
                                                Container(
                                          width: (context.w *
                                                  0.14)
                                              .clamp(44.0, 60.0),
                                          height: (context.w *
                                                  0.14)
                                              .clamp(44.0, 60.0),
                                          color:
                                              OxroColors.primary,
                                          alignment:
                                              Alignment.center,
                                          child: Text('O',
                                              style: TextStyle(
                                                  fontSize: context
                                                      .font(26),
                                                  fontWeight:
                                                      FontWeight
                                                          .w800,
                                                  color: Colors
                                                      .white)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(10)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal:
                                            context.padX + 4),
                                    child: Text(
                                      'Verify the email id',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize:
                                              context.font(15),
                                          fontWeight:
                                              FontWeight.w800,
                                          color: OxroColors.dark),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(4)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal:
                                            context.padX + 4),
                                    child: Wrap(
                                      alignment:
                                          WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          'Code sent to $_masked  ',
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                              fontSize: context
                                                  .font(13),
                                              color:
                                                  OxroColors.muted),
                                        ),
                                        GestureDetector(
                                          onTap: () => Navigator.of(
                                                  context)
                                              .maybePop(),
                                          child: Text('Change',
                                              style: TextStyle(
                                                  fontSize: context
                                                      .font(13),
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                  color: OxroColors
                                                      .blue)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: context.rs(14)),
                                  // 6 native fields — tap opens
                                  // the phone's number keyboard.
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: context.padX),
                                    child: AnimatedBuilder(
                                      animation: _shake,
                                      builder: (context, child) {
                                        final dx = _shake
                                                    .value ==
                                                0
                                            ? 0.0
                                            : 8 *
                                                math.sin(_shake
                                                        .value *
                                                    math.pi *
                                                    3);
                                        return Transform.translate(
                                          offset: Offset(dx, 0),
                                          child: child,
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children:
                                            List.generate(6, (i) {
                                          final active =
                                              i == _pos &&
                                                  !_success;
                                          return AnimatedContainer(
                                            duration:
                                                const Duration(
                                                    milliseconds:
                                                        180),
                                            width: boxSize,
                                            height: boxSize + 4,
                                            alignment:
                                                Alignment.center,
                                            decoration:
                                                BoxDecoration(
                                              color: _success
                                                  ? const Color(
                                                      0xFFE6F7EC)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          10),
                                              border: Border.all(
                                                color: _success
                                                    ? Colors.green
                                                    : _error !=
                                                            null
                                                        ? Colors.red
                                                        : active
                                                            ? OxroColors
                                                                .primary
                                                            : OxroColors
                                                                .muted,
                                                width: active ||
                                                        _success
                                                    ? 1.8
                                                    : 1,
                                              ),
                                            ),
                                            child: ScaleTransition(
                                              scale: Tween<double>(
                                                      begin: 0.6,
                                                      end: 1.0)
                                                  .animate(CurvedAnimation(
                                                      parent:
                                                          _pop,
                                                      curve: Curves
                                                          .easeOutBack)),
                                              child: TextField(
                                                controller:
                                                    _ctrls[i],
                                                focusNode:
                                                    _nodes[i],
                                                autofocus:
                                                    i == 0,
                                                textAlign:
                                                    TextAlign.center,
                                                keyboardType:
                                                    TextInputType
                                                        .number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly
                                                ],
                                                textInputAction:
                                                    i < 5
                                                        ? TextInputAction
                                                            .next
                                                        : TextInputAction
                                                            .done,
                                                onSubmitted: (_) {
                                                  if (i == 5) {
                                                    _verify();
                                                  }
                                                },
                                                onTap: () =>
                                                    setState(
                                                        () =>
                                                            _pos =
                                                                i),
                                                onChanged: (v) =>
                                                    _handleChanged(
                                                        i, v),
                                                style: TextStyle(
                                                  fontSize: context
                                                      .font(18),
                                                  fontWeight:
                                                      FontWeight
                                                          .w700,
                                                  color: _success
                                                      ? Colors.green
                                                          .shade800
                                                      : OxroColors
                                                          .dark,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                  border:
                                                      InputBorder
                                                          .none,
                                                  counterText:
                                                      '',
                                                  contentPadding:
                                                      EdgeInsets
                                                          .zero,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                  if (_error != null)
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          context.padX + 4,
                                          context.rs(8),
                                          context.padX + 4,
                                          0),
                                      child: Text(_error!,
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                              fontSize: context
                                                  .font(12.5),
                                              color: Colors.red,
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                    ),
                                  // Timer — small centered grey.
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        context.padX + 4,
                                        context.rs(10),
                                        context.padX + 4,
                                        0),
                                    child: Center(
                                      child: _left > 0
                                          ? Text(
                                              'Resend OTP in 00:${_left.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                  fontSize: context
                                                      .font(12),
                                                  color: OxroColors
                                                      .muted))
                                          : GestureDetector(
                                              onTap: _resend,
                                              child: Text(
                                                  'Resend OTP',
                                                  style: TextStyle(
                                                      fontSize: context
                                                          .font(
                                                              12.5),
                                                      fontWeight:
                                                          FontWeight
                                                              .w700,
                                                      color: OxroColors
                                                          .primary)),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: context.rs(16)),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                        context.padX,
                                        0,
                                        context.padX,
                                        context.rs(6)),
                                    child: OxroButton(
                                        label: 'Verify',
                                        onTap: _verify),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Success overlay — premium burst animation.
                if (_success)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.75),
                      alignment: Alignment.center,
                      child: const _SuccessBurst(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
          ],
        ),
      ),
    );
  }
}

/// Premium verify-success burst: elastic pop + expanding rings +
/// hand-drawn tick + confetti dots. Plays once, then home.
class _SuccessBurst extends StatefulWidget {
  const _SuccessBurst();

  @override
  State<_SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<_SuccessBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _pop;
  late final Animation<double> _ring1;
  late final Animation<double> _ring2;
  late final Animation<double> _tick;
  late final Animation<double> _confetti;

  static const _confettiColors = [
    OxroColors.primary,
    OxroColors.blue,
    Colors.green,
    Color(0xFFFFC107),
    Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    _pop = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut));
    _ring1 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut));
    _ring2 = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut));
    _tick = CurvedAnimation(
        parent: _c,
        curve:
            const Interval(0.35, 0.7, curve: Curves.easeOutCubic));
    _confetti = CurvedAnimation(
        parent: _c,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const ValueKey('otp_success_tick'),
      animation: _c,
      builder: (context, child) {
        final circle = context.rs(96);
        return SizedBox(
          width: circle + 120,
          height: circle + 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Expanding rings.
              _ring(96 + 90 * _ring1.value, 1 - _ring1.value),
              _ring(96 + 90 * _ring2.value, 1 - _ring2.value),
              // Confetti dots.
              for (var i = 0; i < 14; i++)
                _dot(i, _confetti.value),
              // Elastic green circle.
              Transform.scale(
                scale: _pop.value.clamp(0.01, 1.4),
                child: Container(
                  width: circle,
                  height: circle,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x5566BB6A),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                ),
              ),
              // Hand-drawn tick.
              CustomPaint(
                size: Size.square(context.rs(52)),
                painter: _CheckPainter(_tick.value),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.5 * opacity),
          width: 3,
        ),
      ),
    );
  }

  Widget _dot(int i, double t) {
    final angle = (i / 14) * math.pi * 2 + 0.3;
    final dist = 60 + 70 * t;
    final color = _confettiColors[i % _confettiColors.length];
    return Positioned(
      left: 110 + dist * math.cos(angle) - 5,
      top: 110 + dist * math.sin(angle) - 5,
      child: Opacity(
        opacity: (1 - t).clamp(0.0, 1.0),
        child: Container(
          width: 10 - (i % 3) * 2,
          height: 10 - (i % 3) * 2,
          decoration: BoxDecoration(
            color: color,
            shape:
                i.isEven ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: i.isEven
                ? null
                : BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Draws the check stroke progressively (0..1).
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.24, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.30);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = path.computeMetrics().toList();
    final total =
        metrics.fold<double>(0, (s, m) => s + m.length);
    var drawn = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (drawn <= 0) break;
      final len = math.min(drawn, m.length);
      canvas.drawPath(m.extractPath(0, len), paint);
      drawn -= len;
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress;
}
