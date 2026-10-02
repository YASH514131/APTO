import 'package:flutter/material.dart';

/// Renders the iconic 3-bar Solana logo emblem matching the rewards design.
class SolanaEmblemWidget extends StatelessWidget {
  final double size;
  final Color color;

  const SolanaEmblemWidget({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF3BE3D4),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.82,
      child: CustomPaint(
        painter: _SolanaLogoPainter(color: color),
      ),
    );
  }
}

class _SolanaLogoPainter extends CustomPainter {
  final Color color;

  _SolanaLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final barH = h * 0.22;
    final skew = w * 0.24;
    final r = Radius.circular(barH * 0.45);

    // 1. Top Bar (leaning right)
    final path1 = Path();
    path1.moveTo(skew, 0);
    path1.lineTo(w, 0);
    path1.lineTo(w - skew, barH);
    path1.lineTo(0, barH);
    path1.close();
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, barH), r),
      paint,
    );

    // Precise 3 slanted bars
    canvas.save();
    // Clear and draw authentic 3 slanted parallelograms with rounded styling
    // Bar 1 (Top: left to right slant)
    _drawSlantedBar(canvas, paint, 0, 0, w, barH, skew, true);
    // Bar 2 (Middle: right to left slant)
    _drawSlantedBar(canvas, paint, 0, h * 0.39, w, barH, skew, false);
    // Bar 3 (Bottom: left to right slant)
    _drawSlantedBar(canvas, paint, 0, h * 0.78, w, barH, skew, true);
    canvas.restore();
  }

  void _drawSlantedBar(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double width,
    double height,
    double skew,
    bool pointRight,
  ) {
    final path = Path();
    final r = height * 0.35;

    if (pointRight) {
      path.moveTo(x + skew + r, y);
      path.lineTo(x + width - r, y);
      path.arcToPoint(Offset(x + width, y + r), radius: Radius.circular(r));
      path.lineTo(x + width - skew - r, y + height);
      path.lineTo(x + r, y + height);
      path.arcToPoint(Offset(x, y + height - r), radius: Radius.circular(r));
      path.close();
    } else {
      path.moveTo(x + width - skew - r, y);
      path.lineTo(x + r, y);
      path.arcToPoint(Offset(x, y + r), radius: Radius.circular(r));
      path.lineTo(x + skew + r, y + height);
      path.lineTo(x + width - r, y + height);
      path.arcToPoint(Offset(x + width, y + height - r), radius: Radius.circular(r));
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SolanaLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
