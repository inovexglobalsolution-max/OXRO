import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/theme/responsive.dart';
import 'package:oxro/features/applock/data/applock_store.dart';

/// Set a new 4-digit PIN: enter + confirm.
/// Pops true when enabled.
class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen>
    with SingleTickerProviderStateMixin {
  String _first = '';
  String _second = '';
  String? _error;
  late final AnimationController _shake;

  bool get _confirming => _first.length == 4;
  String get _pin => _confirming ? _second : _first;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _fail(String msg) {
    setState(() => _error = msg);
    _shake.forward(from: 0);
    HapticFeedback.mediumImpact();
  }

  Future<void> _press(String d) async {
    if (_pin.length >= 4) return;
    setState(() {
      if (_confirming) {
        _second += d;
      } else {
        _first += d;
      }
      _error = null;
    });
    HapticFeedback.selectionClick();
    if (_pin.length == 4) {
      if (!_confirming) {
        setState(() {});
        return;
      }
      if (_first != _second) {
        setState(() {
          _first = '';
          _second = '';
        });
        _fail('PINs do not match — try again');
        return;
      }
      final ok =
          await ApplockStore.instance.enable(_first, _second);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _fail('Invalid PIN — 4 digits only');
      }
    }
  }

  void _backspace() {
    setState(() {
      if (_confirming && _second.isNotEmpty) {
        _second = _second.substring(0, _second.length - 1);
      } else if (!_confirming && _first.isNotEmpty) {
        _first = _first.substring(0, _first.length - 1);
      } else if (_confirming && _second.isEmpty) {
        _first = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: context.maxContentW),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.rs(8),
                      vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .maybePop(),
                        icon: const Icon(Icons.arrow_back,
                            color: OxroColors.charcoal),
                      ),
                      const Expanded(
                        child: Text('Set app PIN',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.w800)),
                      ),
                      if (_confirming)
                        GestureDetector(
                          key: const ValueKey(
                              'pin_restart'),
                          onTap: () => setState(() {
                            _first = '';
                            _second = '';
                            _error = null;
                          }),
                          child: const Text('Restart',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                  color:
                                      OxroColors.primary)),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: context.rs(16)),
                Text(
                    _confirming
                        ? 'Confirm your PIN'
                        : 'Choose a 4-digit PIN',
                    style: TextStyle(
                        fontSize: context.font(20),
                        fontWeight: FontWeight.w800,
                        color: OxroColors.dark)),
                SizedBox(height: context.rs(16)),
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
                                  'pin_set_dot_$i'),
                              width: 18,
                              height: 18,
                              margin:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _pin.length
                                    ? OxroColors.primary
                                    : Colors.white,
                                border: Border.all(
                                    color:
                                        OxroColors.primary,
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
                    padding:
                        EdgeInsets.only(top: context.rs(10)),
                    child: Text(_error!,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.red,
                            fontWeight: FontWeight.w600)),
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
                        key: const ValueKey('pin_set_back'),
                        onTap: _backspace,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: OxroColors.pageBg,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                              Icons.backspace_outlined,
                              color: OxroColors.muted),
                        ),
                      );
                    }
                    return _key(
                        '${i + 1}', () => _press('${i + 1}'));
                  },
                ),
                SizedBox(height: context.rs(20)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _key(String d, VoidCallback onTap) {
    return GestureDetector(
      key: ValueKey('pin_set_key_$d'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OxroColors.border),
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
