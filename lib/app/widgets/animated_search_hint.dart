import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A quiet rotating hint for search fields. It cycles real catalogue names
/// with a fade, rise and slight scale so the field feels alive without
/// stealing focus or affecting layout.
class AnimatedSearchHint extends StatefulWidget {
  const AnimatedSearchHint({
    super.key,
    required this.items,
    this.fallback = 'Search dishes, kitchens and cuisines',
    this.hintKey = 'search_hint',
    this.interval = const Duration(milliseconds: 2800),
    this.duration = const Duration(milliseconds: 460),
    this.style,
    this.emphasisStyle,
    this.semanticLabel = 'Search dishes',
  });

  final List<String> items;
  final String fallback;
  final String hintKey;
  final Duration interval;
  final Duration duration;
  final TextStyle? style;

  /// Style for text wrapped in double quotes (e.g. the rotating dish name).
  final TextStyle? emphasisStyle;
  final String semanticLabel;

  @override
  State<AnimatedSearchHint> createState() => _AnimatedSearchHintState();
}

class _AnimatedSearchHintState extends State<AnimatedSearchHint> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant AnimatedSearchHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.items, widget.items) ||
        oldWidget.interval != widget.interval) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final count = widget.items.length;
    if (count < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % count);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  TextSpan _labelSpan(String label) {
    final emphasis = widget.emphasisStyle;
    if (emphasis == null) {
      return TextSpan(text: label);
    }
    return TextSpan(text: label, style: emphasis);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final label = items.isEmpty
        ? widget.fallback
        : items[_index % items.length];
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : widget.duration;
    final style =
        widget.style ??
        Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: ExcludeSemantics(
        child: ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: duration,
              reverseDuration: duration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.45),
                      end: Offset.zero,
                    ).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
                      child: child,
                    ),
                  ),
                );
              },
              child: FittedBox(
                key: ValueKey(
                  '${widget.hintKey}_${_index % (items.isEmpty ? 1 : items.length)}',
                ),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  _labelSpan(label),
                  maxLines: 1,
                  softWrap: false,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
