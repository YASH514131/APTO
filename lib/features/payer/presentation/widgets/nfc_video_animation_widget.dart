import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../core/theme/app_theme.dart';

/// A responsive, premium NFC card widget with reveal animation.
///
/// Features:
/// - Continuous looping of the primary `nfc_wave.mp4` video with audio focus mixing.
/// - Revealed `nfc_chip.mp4` on demand when card slides up.
/// - Scaled-up chip animation with edge-feathering to eliminate dead space.
/// - Glowing Seed Vault hardware lock indicator at the chip center.
/// - 3D floating elevation shadow separating the sliding card from the revealed chip.
class NfcVideoAnimationWidget extends StatefulWidget {
  final String videoPath;
  final bool isRevealed;
  final VoidCallback? onTap;

  const NfcVideoAnimationWidget({
    super.key,
    this.videoPath = 'lib/assets/vedio/nfc_wave.mp4',
    this.isRevealed = false,
    this.onTap,
  });

  @override
  State<NfcVideoAnimationWidget> createState() =>
      _NfcVideoAnimationWidgetState();
}

class _NfcVideoAnimationWidgetState extends State<NfcVideoAnimationWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Main card video (nfc_wave.mp4)
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  // Hidden chip video (nfc_chip.mp4) revealed behind the card
  VideoPlayerController? _chipController;
  bool _chipInitialized = false;

  // Internal reveal toggle (keeps local state in sync)
  bool _internalRevealed = false;

  // Animation controller
  late AnimationController _revealController;
  late Animation<double> _revealCurve;
  late Animation<double> _chipOpacityAnimation;
  late Animation<double> _chipScaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _internalRevealed = widget.isRevealed;

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _revealCurve = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _chipOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.08, 0.60, curve: Curves.easeOut),
      ),
    );

    _chipScaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.05, 0.70, curve: Curves.easeOutBack),
      ),
    );

    _initVideoPlayer();
    _initChipVideoPlayer();

    if (widget.isRevealed) {
      _startReveal();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.play();
      if (_internalRevealed) {
        _chipController?.play();
      }
    }
  }

  @override
  void didUpdateWidget(covariant NfcVideoAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      _internalRevealed = widget.isRevealed;
      if (widget.isRevealed) {
        _startReveal();
      } else {
        _startCollapse();
      }
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      // mixWithOthers: true ensures this player never yields audio/video focus to other players
      _controller = VideoPlayerController.asset(
        widget.videoPath,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0);
      await _controller!.play();

      // Guard: automatically resume if Android or another component momentarily pauses it
      _controller!.addListener(() {
        if (mounted &&
            _isInitialized &&
            _controller != null &&
            !_controller!.value.isPlaying &&
            !_hasError) {
          _controller!.play();
        }
      });

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('NFC main wave video init error with options: $e');
      try {
        _controller = VideoPlayerController.asset(widget.videoPath);
        await _controller!.initialize();
        await _controller!.setLooping(true);
        await _controller!.setVolume(0.0);
        await _controller!.play();
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      } catch (e2) {
        debugPrint('NFC main wave fallback error: $e2');
        if (mounted) {
          setState(() => _hasError = true);
        }
      }
    }
  }

  Future<void> _initChipVideoPlayer() async {
    try {
      _chipController = VideoPlayerController.asset(
        'lib/assets/vedio/nfc_chip.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _chipController!.initialize();
      await _chipController!.setLooping(true);
      await _chipController!.setVolume(0.0);
      _chipController!.addListener(_onChipControllerUpdate);

      if (_internalRevealed) {
        await _chipController!.play();
      } else {
        await _chipController!.pause();
      }

      if (mounted) {
        setState(() => _chipInitialized = true);
      }
    } catch (e) {
      debugPrint('NFC chip video init error (clean): $e');
      try {
        _chipController = VideoPlayerController.asset(
          'lib/assets/vedio/nfc_chip .mp4',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _chipController!.initialize();
        await _chipController!.setLooping(true);
        await _chipController!.setVolume(0.0);
        _chipController!.addListener(_onChipControllerUpdate);

        if (_internalRevealed) {
          await _chipController!.play();
        } else {
          await _chipController!.pause();
        }

        if (mounted) {
          setState(() => _chipInitialized = true);
        }
      } catch (e2) {
        debugPrint('NFC chip video init error (fallback): $e2');
      }
    }
  }

  void _onChipControllerUpdate() {
    if (!mounted || !_chipInitialized || _chipController == null) return;
    final value = _chipController!.value;
    if (_internalRevealed && !value.hasError) {
      if (!value.isPlaying && !value.isBuffering) {
        if (value.duration > Duration.zero &&
            value.position >= value.duration) {
          _chipController!.seekTo(Duration.zero).then((_) {
            if (mounted && _internalRevealed) {
              _chipController!.play();
            }
          });
        } else {
          _chipController!.play();
        }
      }
    }
  }

  void _startReveal() {
    _internalRevealed = true;
    if (_chipInitialized && _chipController != null) {
      _chipController!.seekTo(Duration.zero);
      _chipController!.play();
    }
    _controller?.play(); // keep wave video active while card is raised
    _revealController.forward();
  }

  void _startCollapse() {
    _internalRevealed = false;
    _revealController.reverse().then((_) {
      if (mounted && !_internalRevealed) {
        _chipController?.pause();
      }
    });
    _controller?.play(); // keep wave video active when card is lowered
  }

  void _handleTap() {
    HapticFeedback.lightImpact();

    // Toggle reveal animation
    if (_internalRevealed) {
      _startCollapse();
    } else {
      _startReveal();
    }

    // Also notify parent
    widget.onTap?.call();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.pause();
    _controller?.dispose();
    _chipController?.removeListener(_onChipControllerUpdate);
    _chipController?.pause();
    _chipController?.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final isShortScreen = screenHeight < 700;

    // Slide up offset reveals the chip behind the card
    final double slideUpFraction = isShortScreen ? -0.65 : -0.75;

    final double videoAspect = (_isInitialized &&
            _controller != null &&
            _controller!.value.aspectRatio > 0)
        ? _controller!.value.aspectRatio
        : (16 / 10);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double effectiveWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth > 400 ? 400 : constraints.maxWidth)
            : 360;

        return Center(
          child: SizedBox(
            width: effectiveWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: AnimatedBuilder(
                animation: _revealCurve,
                builder: (context, _) {
                  final revealVal = _revealCurve.value;
                  final slideOffset = Offset(0, slideUpFraction * revealVal);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Layer 1: The revealed NFC chip video with hardware lock focal point
                      Positioned.fill(
                        child: _buildChipLayer(videoAspect, effectiveWidth),
                      ),

                      // Layer 2: The main card (slides upward with 3D elevation)
                      FractionalTranslation(
                        translation: slideOffset,
                        child: Transform.scale(
                          scale: 1.0 + (revealVal * 0.02),
                          child: _buildMainCard(videoAspect, revealVal),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// The hidden NFC chip video layer that appears in the card's original place
  Widget _buildChipLayer(double aspectRatio, double effectiveWidth) {
    final borderRadius = BorderRadius.circular(effectiveWidth < 340 ? 18 : 22);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E232B),
            Color(0xFF051216),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: AppTheme.seedVaultTeal.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seedVaultTeal.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: FadeTransition(
          opacity: _chipOpacityAnimation,
          child: ScaleTransition(
            scale: _chipScaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Zoomed-in chip video (scaled 1.35x to eliminate black border & enlarge circuits)
                if (_chipInitialized && _chipController != null)
                  RepaintBoundary(
                    key: const ValueKey('chip_video_active'),
                    child: SizedBox.expand(
                      child: Transform.scale(
                        scale: 1.35,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: (_chipController!.value.size.width > 0)
                                ? _chipController!.value.size.width
                                : 16.0,
                            height: (_chipController!.value.size.height > 0)
                                ? _chipController!.value.size.height
                                : 9.0,
                            child: VideoPlayer(_chipController!),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Center(
                    key: const ValueKey('chip_video_loading'),
                    child: LoadingAnimationWidget.flickr(
                      leftDotColor: AppTheme.seedVaultTeal,
                      rightDotColor: AppTheme.verifiedGreen,
                      size: 32,
                    ),
                  ),

                // 2. Soft vignette edge blend to eliminate hard borders
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.88,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          const Color(0xFF051216).withValues(alpha: 0.55),
                          const Color(0xFF051216).withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.55, 0.82, 1.0],
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

  /// The main NFC wave card that slides up to reveal the chip
  Widget _buildMainCard(double aspectRatio, double revealProgress) {
    final borderRadius = BorderRadius.circular(22);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF102831),
            Color(0xFF0B1F26),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: AppTheme.seedVaultTeal
              .withValues(alpha: 0.35 + (revealProgress * 0.4)),
          width: 1.5,
        ),
        boxShadow: [
          // Ambient neon glow
          BoxShadow(
            color: AppTheme.seedVaultTeal
                .withValues(alpha: 0.15 + (revealProgress * 0.25)),
            blurRadius: 20 + (revealProgress * 16),
            spreadRadius: 1 + (revealProgress * 3),
            offset: Offset(0, 4 + (revealProgress * 8)),
          ),
          // Deep floating card shadow separating it from the chip below
          if (revealProgress > 0.05)
            BoxShadow(
              color: Colors.black.withValues(alpha: revealProgress * 0.65),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isInitialized && _controller != null
              ? RepaintBoundary(
                  key: const ValueKey('main_video_active'),
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: (_controller!.value.size.width > 0)
                            ? _controller!.value.size.width
                            : 16.0,
                        height: (_controller!.value.size.height > 0)
                            ? _controller!.value.size.height
                            : 9.0,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                )
              : _buildLoadingState(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      key: const ValueKey('main_video_loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_hasError)
            LoadingAnimationWidget.flickr(
              leftDotColor: AppTheme.seedVaultTeal,
              rightDotColor: AppTheme.verifiedGreen,
              size: 40,
            )
          else
            const Icon(
              Icons.contactless_rounded,
              size: 52,
              color: AppTheme.seedVaultTeal,
            ),
          const SizedBox(height: 12),
          Text(
            _hasError ? 'Tap to Pay' : 'Initializing NFC Animation...',
            style: AppTheme.sansBody(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
