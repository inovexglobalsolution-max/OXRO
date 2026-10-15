import 'package:flutter/material.dart';

/// App-wide animated screen transitions.
/// Every next-screen move slides + fades (280ms, easeOutCubic) —
/// no instant jumps anywhere in OXRO.
class OxroPageRoute<T> extends PageRouteBuilder<T> {
  OxroPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration:
              const Duration(milliseconds: 280),
          reverseTransitionDuration:
              const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondary) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondary, child) {
            final slide =
                Tween<Offset>(
                      begin: const Offset(0.25, 0),
                      end: Offset.zero,
                    )
                    .chain(
                        CurveTween(curve: Curves.easeOutCubic))
                    .animate(animation);
            final fade = Tween<double>(begin: 0.0, end: 1.0)
                .chain(CurveTween(curve: Curves.easeOut))
                .animate(animation);
            return SlideTransition(
              position: slide,
              child: FadeTransition(
                  opacity: fade, child: child),
            );
          },
        );
}

/// Push with animation.
Future<T?> pushScreen<T>(
        BuildContext context, Widget screen) =>
    Navigator.of(context)
        .push<T>(OxroPageRoute(builder: (_) => screen));

/// Replace current screen with animation.
Future<T?> replaceScreen<T>(
        BuildContext context, Widget screen) =>
    Navigator.of(context).pushReplacement<T, dynamic>(
        OxroPageRoute(builder: (_) => screen));

/// Clear stack and show screen with animation.
Future<T?> replaceAllWith<T>(
        BuildContext context, Widget screen) =>
    Navigator.of(context).pushAndRemoveUntil<T>(
        OxroPageRoute(builder: (_) => screen), (_) => false);
