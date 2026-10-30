import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Muted looping video banner that falls back to [fallbackAsset] image
/// when the video fails to load or initialize (e.g. in widget tests).
class VideoBanner extends StatefulWidget {
  const VideoBanner({
    super.key,
    required this.asset,
    this.fallbackAsset,
    this.fit = BoxFit.cover,
    this.play = true,
  });

  final String asset;
  final String? fallbackAsset;
  final BoxFit fit;

  /// When false the video pauses (used by carousels for off-screen slides).
  final bool play;

  @override
  State<VideoBanner> createState() => _VideoBannerState();
}

class _VideoBannerState extends State<VideoBanner> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.asset(widget.asset);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (widget.play) await controller.play();
      setState(() => _controller = controller);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant VideoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = _controller;
    if (controller == null || !_failed) {
      if (widget.play && !oldWidget.play) {
        controller?.play();
      } else if (!widget.play && oldWidget.play) {
        controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed || controller == null || !controller.value.isInitialized) {
      final fallback = widget.fallbackAsset;
      if (fallback != null) {
        return Image.asset(
          fallback,
          fit: widget.fit,
          errorBuilder: (context, error, stack) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B2A6B), Color(0xFF3D5AFE)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.restaurant_rounded,
                size: 48,
                color: Colors.white54,
              ),
            ),
          ),
        );
      }
      return const ColoredBox(color: Color(0xFF1B2A6B));
    }
    final size = controller.value.size;
    if (size.isEmpty) {
      return const ColoredBox(color: Color(0xFF1B2A6B));
    }
    return ClipRect(
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
