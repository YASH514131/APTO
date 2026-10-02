import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScratchCardWidget extends StatefulWidget {
  final Widget revealedChild;
  final VoidCallback? onThresholdReached;
  final double thresholdPercent;
  final double width;
  final double height;

  const ScratchCardWidget({
    super.key,
    required this.revealedChild,
    this.onThresholdReached,
    this.thresholdPercent = 0.35,
    this.width = 310,
    this.height = 180,
  });

  @override
  State<ScratchCardWidget> createState() => _ScratchCardWidgetState();
}

class _ScratchCardWidgetState extends State<ScratchCardWidget>
    with SingleTickerProviderStateMixin {
  final Path _scratchedPath = Path();
  int _pointCount = 0;
  final Set<int> _scratchedGrid = {};
  bool _isThresholdReached = false;
  double _wipeProgress = 0.0;
  late AnimationController _wipeController;

  static const int _cols = 16;
  static const int _rows = 9;
  static const int _totalGrid = _cols * _rows;

  @override
  void initState() {
    super.initState();
    _wipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..addListener(() {
        setState(() {
          _wipeProgress = Curves.easeInOutCubic.transform(_wipeController.value);
        });
      });
  }

  @override
  void dispose() {
    _wipeController.dispose();
    super.dispose();
  }

  void _onPanStart(Offset local) {
    if (_isThresholdReached) return;
    setState(() {
      _scratchedPath.moveTo(local.dx, local.dy);
      _pointCount++;
    });
    _updateGrid(local);
  }

  void _onPanUpdate(Offset local) {
    if (_isThresholdReached) return;
    if (local.dx >= 0 &&
        local.dx <= widget.width &&
        local.dy >= 0 &&
        local.dy <= widget.height) {
      setState(() {
        _scratchedPath.lineTo(local.dx, local.dy);
        _pointCount++;
      });
      _updateGrid(local);
    }
  }

  void _updateGrid(Offset local) {
    final c = (local.dx / widget.width * _cols).floor().clamp(0, _cols - 1);
    final r = (local.dy / widget.height * _rows).floor().clamp(0, _rows - 1);
    _scratchedGrid.add(r * _cols + c);

    final ratio = _scratchedGrid.length / _totalGrid;
    if (ratio >= widget.thresholdPercent && !_isThresholdReached) {
      _isThresholdReached = true;
      HapticFeedback.heavyImpact();
      _wipeController.forward().then((_) {
        widget.onThresholdReached?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Revealed reward content
            widget.revealedChild,

            // Layer 2: Metallic silver-lavender foil surface with smooth 60fps path drawing
            if (_wipeProgress < 1.0)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (e) => _onPanStart(e.localPosition),
                onPanUpdate: (e) => _onPanUpdate(e.localPosition),
                child: CustomPaint(
                  painter: _FoilScratchPainter(
                    scratchedPath: _scratchedPath,
                    pointCount: _pointCount,
                    wipeProgress: _wipeProgress,
                  ),
                  size: Size(widget.width, widget.height),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FoilScratchPainter extends CustomPainter {
  final Path scratchedPath;
  final int pointCount;
  final double wipeProgress;

  _FoilScratchPainter({
    required this.scratchedPath,
    required this.pointCount,
    required this.wipeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw smooth metallic silver to soft lavender gradient foil (matching reference screenshot)
    final foilPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size.width, size.height),
        [
          const Color(0xFFD6DCE8), // Silver grey top-left
          const Color(0xFFBAC5DA), // Soft slate silver
          const Color(0xFF8F9ECC), // Soft lavender blue bottom-right
        ],
        [0.0, 0.45, 1.0],
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(22),
      ),
      foilPaint,
    );

    // Subtle inner border highlight
    final innerBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(21),
      ),
      innerBorder,
    );

    // Centered "S" Watermark & Text Prompt
    if (pointCount < 15 && wipeProgress == 0.0) {
      // Large "S" Watermark in the middle
      final sPainter = TextPainter(
        text: TextSpan(
          text: 'S',
          style: TextStyle(
            color: const Color(0xFF3B4861).withValues(alpha: 0.22),
            fontSize: 58,
            fontWeight: FontWeight.w900,
            fontFamily: 'Roboto',
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      sPainter.paint(
        canvas,
        Offset(
          (size.width - sPainter.width) / 2,
          (size.height - sPainter.height) / 2 - 24,
        ),
      );

      // "SCRATCH WITH FINGER" & "Reveal your reward"
      final textPainter = TextPainter(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'SCRATCH WITH FINGER\n',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.4,
              ),
            ),
            TextSpan(
              text: 'Reveal your reward',
              style: TextStyle(
                color: Color(0xFF718096),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 40);

      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2 + 16,
        ),
      );
    }

    // 2. Clear out scratched paths using single continuous hardware-accelerated Path
    final eraser = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 48
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(scratchedPath, eraser);

    // 3. Automated wipe off transition across the card
    if (wipeProgress > 0.0) {
      final wipeX = size.width * wipeProgress * 1.35;
      final wipePath = Path()
        ..moveTo(0, 0)
        ..lineTo(wipeX, 0)
        ..lineTo(wipeX - 45, size.height)
        ..lineTo(0, size.height)
        ..close();

      canvas.drawPath(wipePath, eraser);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FoilScratchPainter oldDelegate) {
    return oldDelegate.pointCount != pointCount ||
        oldDelegate.wipeProgress != wipeProgress;
  }
}
