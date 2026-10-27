import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:oxro/app/theme/app_colors.dart';
import 'package:oxro/app/widgets/veg_mark.dart';
import 'package:oxro/features/home/data/food_preference_store.dart';

/// What the user picked in the food-preference dialog.
enum FoodSheetChoice { veg, nonVeg, moreSettings }

Color _accentFor(FoodPreference preference) => preference == FoodPreference.veg
    ? OxroColors.vegGreen
    : OxroColors.nonVegRed;

/// Floating veg / non-veg choice card.
Future<FoodSheetChoice?> showFoodPreferenceSheet(
  BuildContext context, {
  FoodPreference preference = FoodPreference.veg,
}) {
  return showGeneralDialog<FoodSheetChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Food preference',
    barrierColor: Colors.black.withValues(alpha: 0.52),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      return SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.22),
          child: _FoodSheetBody(preference: preference),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FoodSheetBody extends StatefulWidget {
  const _FoodSheetBody({required this.preference});

  final FoodPreference preference;

  @override
  State<_FoodSheetBody> createState() => _FoodSheetBodyState();
}

class _FoodSheetBodyState extends State<_FoodSheetBody> {
  late FoodPreference _preference = widget.preference;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(_preference);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              key: const ValueKey('veg_sheet'),
              color: Colors.white,
              elevation: 18,
              shadowColor: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What would you like to see?',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: OxroColors.charcoal,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Your choice stays on across the app.',
                      style: TextStyle(fontSize: 12.5, color: OxroColors.muted),
                    ),
                    const SizedBox(height: 20),
                    _PreferenceOption(
                      key: const ValueKey('food_pref_veg'),
                      label: 'Veg only',
                      caption: 'Show veg dishes from all restaurants',
                      preference: FoodPreference.veg,
                      selected: _preference == FoodPreference.veg,
                      onTap: () =>
                          setState(() => _preference = FoodPreference.veg),
                    ),
                    const SizedBox(height: 12),
                    _PreferenceOption(
                      key: const ValueKey('food_pref_nonveg'),
                      label: 'Non-Veg only',
                      caption: 'Show non-veg dishes from all restaurants',
                      preference: FoodPreference.nonVeg,
                      selected: _preference == FoodPreference.nonVeg,
                      onTap: () =>
                          setState(() => _preference = FoodPreference.nonVeg),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('veg_apply'),
                        onPressed: () => Navigator.of(context).pop(
                          _preference == FoodPreference.nonVeg
                              ? FoodSheetChoice.nonVeg
                              : FoodSheetChoice.veg,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        key: const ValueKey('veg_more_settings'),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(FoodSheetChoice.moreSettings),
                        style: TextButton.styleFrom(
                          foregroundColor: OxroColors.muted,
                        ),
                        child: const Text(
                          'More settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: 48,
              child: Transform.rotate(
                angle: 0.785398,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(3)),
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

class _PreferenceOption extends StatelessWidget {
  const _PreferenceOption({
    super.key,
    required this.label,
    required this.caption,
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String caption;
  final FoodPreference preference;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(preference);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.075) : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? accent : OxroColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? accent : const Color(0xFFB9C2CC),
                  width: selected ? 2.2 : 1.8,
                ),
              ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: selected ? 1 : 0,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            VegMark(veg: preference == FoodPreference.veg, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: OxroColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: OxroColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen 100% VEG / NON-VEG confirmation. Animated, then auto-dismisses.
class FoodPreferenceTransitionScreen extends StatefulWidget {
  const FoodPreferenceTransitionScreen({super.key, required this.preference});

  final FoodPreference preference;

  @override
  State<FoodPreferenceTransitionScreen> createState() =>
      _FoodPreferenceTransitionScreenState();
}

class _FoodPreferenceTransitionScreenState
    extends State<FoodPreferenceTransitionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1900),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _dismissTimer?.cancel();
            _dismissTimer = Timer(const Duration(milliseconds: 260), _dismiss);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.value = 1;
      _dismissTimer = Timer(const Duration(milliseconds: 650), _dismiss);
    } else {
      _controller.forward();
    }
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final veg = widget.preference == FoodPreference.veg;
    final accent = _accentFor(widget.preference);
    final pale = veg ? const Color(0xFFDDF2E5) : const Color(0xFFF8DFDF);
    final message = veg
        ? 'Explore veg dishes from all restaurants'
        : 'Explore non-veg dishes from all restaurants';
    return Scaffold(
      key: const ValueKey('veg_transition'),
      backgroundColor: Colors.white,
      body: AbsorbPointer(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final wash = Curves.easeOutCubic.transform(_interval(t, 0, 0.45));
              final ringProgress = _interval(t, 0, 0.72);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.9,
                          colors: [
                            accent.withValues(alpha: 0.15 * wash),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 3; i++)
                    _AnimatedRing(
                      key: ValueKey('veg_transition_ring_$i'),
                      size: w * (1.55 - i * 0.28),
                      color: i == 2 ? accent : pale,
                      progress: _interval(
                        ringProgress,
                        i * 0.12,
                        i * 0.12 + 0.62,
                      ),
                      accent: accent,
                    ),
                  _BurstPainter(
                    progress: _interval(t, 0.08, 0.68),
                    color: accent,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _curve(t, 0.10, 0.30),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.35, end: 1).animate(
                            CurvedAnimation(
                              parent: _controller,
                              curve: const Interval(
                                0.10,
                                0.52,
                                curve: Curves.elasticOut,
                              ),
                            ),
                          ),
                          child: Container(
                            width: 98,
                            height: 98,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Text(
                              veg ? '100%\nVEG' : 'NON-\nVEG',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: veg ? 27 : 23,
                                height: 0.92,
                                fontWeight: FontWeight.w900,
                                color: accent,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _curve(t, 0.38, 0.62),
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.28),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _controller,
                                  curve: const Interval(
                                    0.38,
                                    0.70,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                              ),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5B6168),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

double _interval(double value, double begin, double end) {
  if (end <= begin) return value >= end ? 1 : 0;
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0);
}

Animation<double> _curve(double value, double begin, double end) {
  return AlwaysStoppedAnimation<double>(
    Curves.easeOut.transform(_interval(value, begin, end)),
  );
}

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    super.key,
    required this.size,
    required this.color,
    required this.progress,
    required this.accent,
  });

  final double size;
  final Color color;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    final opacity = (1 - progress) * 0.9;
    return Transform.scale(
      scale: 0.34 + eased * 0.78,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: progress > 0.82 ? Color.lerp(color, accent, 0.4)! : color,
              width: 2.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends StatelessWidget {
  const _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BurstPainterDelegate(progress: progress, color: color),
        size: const Size.square(340),
      ),
    );
  }
}

class _BurstPainterDelegate extends CustomPainter {
  const _BurstPainterDelegate({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(progress);
    final paint = Paint()..color = color;
    for (var i = 0; i < 12; i++) {
      final angle = (math.pi * 2 / 12) * i - math.pi / 2;
      final radius = 48 + eased * 118;
      final dot = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final fade = (1 - progress).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: 0.7 * fade);
      canvas.drawCircle(dot, 2.8 - progress * 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainterDelegate oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Compact settings surface for the dialog's "More settings" action.
Future<void> showFoodSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => const _FoodSettingsBody(),
  );
}

class _FoodSettingsBody extends StatelessWidget {
  const _FoodSettingsBody();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: FoodPreferenceStore.instance,
        builder: (context, _) {
          final store = FoodPreferenceStore.instance;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DFE5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Food preference',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: OxroColors.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  key: const ValueKey('veg_settings_enabled'),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                  activeTrackColor: _accentFor(store.preference),
                  title: const Text(
                    'Only my preference',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Filter dishes and restaurants'),
                  value: store.enabled,
                  onChanged: (on) {
                    if (on) {
                      store.apply(store.preference);
                    } else {
                      store.disable();
                    }
                  },
                ),
                const SizedBox(height: 6),
                RadioGroup<FoodPreference>(
                  groupValue: store.preference,
                  onChanged: (value) {
                    if (value == null) return;
                    store.apply(value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<FoodPreference>(
                        key: ValueKey('food_settings_veg'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: FoodPreference.veg,
                        activeColor: OxroColors.vegGreen,
                        title: Text('Veg only'),
                      ),
                      RadioListTile<FoodPreference>(
                        key: ValueKey('food_settings_nonveg'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: FoodPreference.nonVeg,
                        activeColor: OxroColors.nonVegRed,
                        title: Text('Non-Veg only'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentFor(store.preference),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
