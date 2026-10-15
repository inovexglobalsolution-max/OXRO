import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/applock/data/applock_store.dart';

/// PIN gate — launch lock + disable-confirm.
/// Calls [onUnlock] only after a correct PIN.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.onUnlock, this.title});

  final VoidCallback onUnlock;
  final String? title;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String? _error;
  int _wrong = 0;
  Timer? _coolTimer;
  int _coolLeft = 0;
  late final AnimationController _shake;
  late final AnimationController _bg;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bg = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _coolTimer?.cancel();
    _shake.dispose();
    _bg.dispose();
    super.dispose();
  }

  void _fail(String msg) {
    setState(() => _error = msg);
    _shake.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  Future<void> _press(String d) async {
    if (_coolLeft > 0) return;
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    HapticFeedback.selectionClick();
    if (_pin.length == 4) {
      final ok =
          await ApplockStore.instance.verify(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlock();
      } else {
        _wrong++;
        if (_wrong >= 5) {
          setState(() {
            _pin = '';
            _coolLeft = 30;
          });
          _fail('Too many tries — wait 30s');
          _coolTimer?.cancel();
          _coolTimer =
              Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) return;
            if (_coolLeft <= 1) {
              t.cancel();
              setState(() {
                _coolLeft = 0;
                _wrong = 0;
                _error = null;
              });
            } else {
              setState(() => _coolLeft--);
            }
          });
        } else {
          final lock = ApplockStore.instance.lockLeft;
          setState(() => _pin = '');
          _fail(lock > 0
              ? 'Wrong PIN — wait ${lock}s'
              : 'Wrong PIN (${5 - _wrong} tries left)');
        }
      }
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
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
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bg,
                builder: (context, _) {
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
                        bottom: -90,
                        left: -70,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: OxroColors.royalBlue
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
                  constraints: BoxConstraints(
                      maxWidth: context.maxContentW),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: OxroColors.gradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x55051D47),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_outline,
                            color: Colors.white, size: 30),
                      ),
                      SizedBox(height: context.rs(12)),
                      Text(widget.title ?? 'Enter app PIN',
                          style: TextStyle(
                              fontSize: context.font(20),
                              fontWeight: FontWeight.w800,
                              color: OxroColors.dark)),
                      SizedBox(height: context.rs(4)),
                      Text(
                          _coolLeft > 0
                              ? 'Locked for ${_coolLeft}s'
                              : 'Your OXRO is locked',
                          style: TextStyle(
                              fontSize: context.font(13),
                              color: OxroColors.muted)),
                      SizedBox(height: context.rs(18)),
                      AnimatedBuilder(
                        animation: _shake,
                        builder: (context, _) {
                          final dx = _shake.value == 0
                              ? 0.0
                              : 8 *
                                  math.sin(_shake.value *
                                      math.pi *
                                      3);
                          return Transform.translate(
                            offset: Offset(dx, 0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Container(
                                    key: ValueKey(
                                        'pin_dot_$i'),
                                    width: 18,
                                    height: 18,
                                    margin:
                                        const EdgeInsets
                                            .symmetric(
                                            horizontal: 8),
                                    decoration: BoxDecoration(
                                      shape:
                                          BoxShape.circle,
                                      color: i <
                                              _pin.length
                                          ? OxroColors
                                              .primary
                                          : Colors.white,
                                      border: Border.all(
                                          color: OxroColors
                                              .primary,
                                          width: 1.5),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_error != null)
                        Padding(
                          padding: EdgeInsets.only(
                              top: context.rs(10)),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.red,
                                  fontWeight:
                                      FontWeight.w600)),
                        ),
                      const Spacer(),
                      GridView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                            horizontal: context.padX),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.8,
                        ),
                        itemCount: 12,
                        itemBuilder: (_, i) {
                          if (i == 9) {
                            return const SizedBox.shrink();
                          }
                          if (i == 10) {
                            return _key('0', () => _press('0'));
                          }
                          if (i == 11) {
                            return GestureDetector(
                              key: const ValueKey(
                                  'pin_back'),
                              onTap: _backspace,
                              behavior:
                                  HitTestBehavior.opaque,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                          14),
                                ),
                                child: const Icon(
                                    Icons.backspace_outlined,
                                    color: OxroColors.muted),
                              ),
                            );
                          }
                          return _key('${i + 1}',
                              () => _press('${i + 1}'));
                        },
                      ),
                      SizedBox(height: context.rs(20)),
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

  Widget _key(String d, VoidCallback onTap) {
    return GestureDetector(
      key: ValueKey('pin_key_$d'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14051D47),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(d,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: OxroColors.charcoal)),
      ),
    );
  }
}
