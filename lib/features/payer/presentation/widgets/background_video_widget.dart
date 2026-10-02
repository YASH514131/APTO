import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';

class BackgroundVideoWidget extends StatefulWidget {
  final String videoPath;
  final Widget child;
  final double overlayOpacity;

  const BackgroundVideoWidget({
    super.key,
    this.videoPath = 'lib/assets/vedio/ripple.mp4',
    required this.child,
    this.overlayOpacity = 0.70,
  });

  @override
  State<BackgroundVideoWidget> createState() => _BackgroundVideoWidgetState();
}

class _BackgroundVideoWidgetState extends State<BackgroundVideoWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        widget.videoPath,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0.0);
      _controller!.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // RepaintBoundary isolates video frame updates from main UI thread
        if (_isInitialized && _controller != null)
          Positioned.fill(
            child: RepaintBoundary(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 300,
                    height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 600,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: AppTheme.background),
          ),

        // Dark Gradient Overlay for high-contrast text legibility
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.background.withValues(alpha: widget.overlayOpacity - 0.1),
                  AppTheme.background.withValues(alpha: widget.overlayOpacity),
                  AppTheme.background.withValues(alpha: widget.overlayOpacity + 0.15),
                ],
              ),
            ),
          ),
        ),

        // Foreground UI Content
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}
