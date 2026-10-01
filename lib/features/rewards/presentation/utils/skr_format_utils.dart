import 'dart:math' as math;

/// Formats SKR reward amount displaying up to [maxDecimals] digits after the point
/// without rounding off (truncating exact fractional digits from backend).
/// 
/// Preserves exact decimals from backend (e.g., 6.601716 -> "6.60171").
/// Cleans redundant trailing zeros down to [minDecimals] (e.g., 0.5 -> "0.50").
String formatSkrAmount(
  double value, {
  int maxDecimals = 5,
  int minDecimals = 2,
}) {
  if (value.isNaN || value.isInfinite) return '0.00';
  if (value == 0.0) return '0.${'0' * minDecimals}';

  // Format to plenty of decimal places to avoid floating point scientific notation
  final fixedStr = value.toStringAsFixed(math.max(maxDecimals + 4, 10));
  final parts = fixedStr.split('.');
  final whole = parts[0];
  var frac = parts.length > 1 ? parts[1] : '';

  // Truncate to maxDecimals without rounding off
  if (frac.length > maxDecimals) {
    frac = frac.substring(0, maxDecimals);
  }

  // Remove trailing zeros down to minDecimals
  while (frac.length > minDecimals && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }

  // Ensure at least minDecimals
  while (frac.length < minDecimals) {
    frac += '0';
  }

  return frac.isEmpty ? whole : '$whole.$frac';
}
