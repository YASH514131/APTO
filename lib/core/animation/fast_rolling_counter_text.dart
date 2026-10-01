import 'package:flutter/material.dart';

/// Fast rolling ticker counter widget that animates counting up from 0 (or previous value) to target value rapidly.
class FastRollingCounterText extends StatefulWidget {
  final double targetValue;
  final TextStyle style;
  final String? prefix;
  final String? suffix;
  final int decimals;
  final Duration duration;

  const FastRollingCounterText({
    super.key,
    required this.targetValue,
    required this.style,
    this.prefix,
    this.suffix,
    this.decimals = 2,
    this.duration = const Duration(milliseconds: 750),
  });

  @override
  State<FastRollingCounterText> createState() => _FastRollingCounterTextState();
}

class _FastRollingCounterTextState extends State<FastRollingCounterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _startValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.targetValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FastRollingCounterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _startValue = _animation.value;
      _animation = Tween<double>(begin: _startValue, end: widget.targetValue).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentVal = _animation.isCompleted ? widget.targetValue : _animation.value;
        final String val;
        if (widget.decimals > 2) {
          // Format with up to widget.decimals places without rounding off
          val = _formatDecimals(currentVal, maxDecimals: widget.decimals);
        } else {
          val = currentVal.toStringAsFixed(widget.decimals);
        }
        final prefixText = widget.prefix ?? '';
        final suffixText = widget.suffix != null ? ' ${widget.suffix}' : '';
        return Text(
          '$prefixText$val$suffixText',
          style: widget.style,
        );
      },
    );
  }

  String _formatDecimals(double value, {required int maxDecimals}) {
    if (value.isNaN || value.isInfinite) return '0.00';
    final fixedStr = value.toStringAsFixed(maxDecimals + 4);
    final parts = fixedStr.split('.');
    final whole = parts[0];
    var frac = parts.length > 1 ? parts[1] : '';
    if (frac.length > maxDecimals) {
      frac = frac.substring(0, maxDecimals);
    }
    while (frac.length > 2 && frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    while (frac.length < 2) {
      frac += '0';
    }
    return '$whole.$frac';
  }
}
